import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/agent_cli.dart';
import '../models/workflow_definition.dart';
import '../models/workflow_run.dart';
import 'event_log_service.dart';
import 'session_manager.dart';
import 'terminal_sessions_controller.dart';

/// DAG workflow scheduler.
///
/// Executes a [WorkflowDefinition] by creating and launching agent sessions
/// according to the graph topology. Listens to terminal exit events to
/// advance through the DAG.
class WorkflowEngine extends ChangeNotifier {
  static const _uuid = Uuid();

  final AppDatabase _db;
  final SessionManager _sessionManager;
  final TerminalSessionsController _terminals;
  final EventLogService _eventLog;

  WorkflowDefinition? _definition;
  WorkflowRun? _currentRun;
  StreamSubscription<({int sessionId, int exitCode})>? _exitSub;

  /// Adjacency: nodeId → outgoing edges.
  Map<String, List<WorkflowEdge>> _successors = {};

  /// Reverse adjacency: nodeId → incoming edges.
  Map<String, List<WorkflowEdge>> _predecessors = {};

  /// Resolved CLI lookup by id.
  Map<String, AgentCli> _cliLookup = {};

  /// Override working directory for all nodes.
  String? _workingDirectory;

  WorkflowEngine(
    this._db,
    this._sessionManager,
    this._terminals,
    this._eventLog,
  );

  /// The active workflow run, or null if idle.
  WorkflowRun? get currentRun => _currentRun;

  /// State of a specific node in the current run.
  NodeRunState? nodeState(String nodeId) => _currentRun?.nodeRuns[nodeId];

  /// All node states in the current run.
  Map<String, NodeRunState> get nodeStates =>
      _currentRun?.nodeRuns ?? const {};

  /// Whether the engine is currently executing a workflow.
  bool get isRunning =>
      _currentRun != null && !_currentRun!.isFinished;

  /// Start executing a workflow definition.
  ///
  /// Throws [StateError] if a workflow is already running.
  /// Throws [ArgumentError] if the definition fails validation.
  Future<WorkflowRun> start(
    WorkflowDefinition definition, {
    String? workingDirectory,
    List<AgentCli> availableClis = const [],
  }) async {
    if (isRunning) {
      throw StateError('A workflow is already running');
    }

    // Validate the DAG.
    final errors = definition.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid workflow: ${errors.join('; ')}');
    }

    _definition = definition;
    _workingDirectory =
        workingDirectory ?? definition.defaultWorkingDirectory;

    // Build CLI lookup from available detected agents.
    _cliLookup = {for (final cli in availableClis) cli.id: cli};

    // Create the run record.
    final runId = _uuid.v4();
    final now = DateTime.now();
    await _db.createWorkflowRun(WorkflowRunsCompanion(
      id: Value(runId),
      definitionId: Value(definition.id),
      definitionName: Value(definition.name),
      definitionJson: Value(
        _encodeDefinitionJson(definition),
      ),
      status: const Value('running'),
      startedAt: Value(now),
    ));

    // Initialize run state.
    final run = WorkflowRun(
      id: runId,
      definitionId: definition.id,
      definitionName: definition.name,
      startedAt: now,
    );
    for (final node in definition.nodes) {
      run.nodeRuns[node.id] = NodeRunState(nodeId: node.id);
    }
    _currentRun = run;

    // Build adjacency maps.
    _successors = {};
    _predecessors = {};
    for (final edge in definition.edges) {
      _successors.putIfAbsent(edge.fromNodeId, () => []).add(edge);
      _predecessors.putIfAbsent(edge.toNodeId, () => []).add(edge);
    }

    // Subscribe to exit events.
    _exitSub = _terminals.exitEvents.listen(_onSessionExited);

    // Log start.
    _eventLog.log(
      ClusterEventKind.workflowStarted,
      sessionName: definition.name,
      detail: '${definition.nodes.length} nodes',
    );

    notifyListeners();

    // Launch root nodes (no incoming edges).
    final hasIncoming = <String>{};
    for (final edge in definition.edges) {
      hasIncoming.add(edge.toNodeId);
    }
    final rootNodes = definition.nodes
        .where((n) => !hasIncoming.contains(n.id))
        .toList();

    for (final node in rootNodes) {
      await _resolveNode(node);
    }

    return run;
  }

  /// Cancel the current workflow run.
  Future<void> cancel() async {
    final run = _currentRun;
    if (run == null || run.isFinished) return;

    // Close all running terminal sessions.
    for (final entry in run.nodeRuns.entries) {
      if (entry.value.status == NodeStatus.running &&
          entry.value.sessionId != null) {
        await _terminals.close(entry.value.sessionId!);
      }
      if (entry.value.status == NodeStatus.pending ||
          entry.value.status == NodeStatus.waiting) {
        entry.value.status = NodeStatus.skipped;
      }
    }

    run.status = WorkflowRunStatus.cancelled;
    run.completedAt = DateTime.now();
    await _db.updateWorkflowRunStatus(
      run.id,
      'cancelled',
      completedAt: run.completedAt,
    );

    _exitSub?.cancel();
    _exitSub = null;

    _eventLog.log(
      ClusterEventKind.workflowCancelled,
      sessionName: run.definitionName,
    );

    notifyListeners();
  }

  /// Retry a failed node by creating a new session and re-evaluating.
  Future<void> retryNode(String nodeId) async {
    final run = _currentRun;
    final def = _definition;
    if (run == null || def == null) return;

    final nodeState = run.nodeRuns[nodeId];
    if (nodeState == null || nodeState.status != NodeStatus.failed) return;

    final node = def.nodes.firstWhere((n) => n.id == nodeId);
    if (node.type != WorkflowNodeType.agentTask) return;

    // Reset node state and re-launch.
    nodeState.status = NodeStatus.pending;
    nodeState.sessionId = null;
    nodeState.output = null;
    nodeState.exitCode = null;
    nodeState.startedAt = null;
    nodeState.completedAt = null;

    // If the run was marked failed, set it back to running.
    if (run.status == WorkflowRunStatus.failed) {
      run.status = WorkflowRunStatus.running;
      await _db.updateWorkflowRunStatus(run.id, 'running');
    }

    await _resolveNode(node);
    notifyListeners();
  }

  @override
  void dispose() {
    _exitSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal: DAG scheduling
  // ---------------------------------------------------------------------------

  /// Resolve a node — launch it or immediately complete virtual nodes.
  Future<void> _resolveNode(WorkflowNode node) async {
    final run = _currentRun;
    if (run == null || run.isFinished) return;

    final state = run.nodeRuns[node.id];
    if (state == null) return;

    switch (node.type) {
      case WorkflowNodeType.fork:
      case WorkflowNodeType.join:
        // Virtual nodes resolve immediately.
        state.status = NodeStatus.completed;
        state.startedAt = DateTime.now();
        state.completedAt = DateTime.now();
        await _evaluateSuccessors(node.id);
      case WorkflowNodeType.agentTask:
        await _launchNode(node);
    }
  }

  /// Launch an agent task node.
  Future<void> _launchNode(WorkflowNode node) async {
    final run = _currentRun;
    final def = _definition;
    if (run == null || def == null) return;

    final state = run.nodeRuns[node.id]!;
    final cli = _cliLookup[node.cliId];
    if (cli == null) {
      // CLI not available — mark as failed.
      state.status = NodeStatus.failed;
      state.completedAt = DateTime.now();
      _eventLog.log(
        ClusterEventKind.workflowNodeFailed,
        sessionName: '${def.name} / ${node.name}',
        detail: 'Agent CLI "${node.cliId}" not detected',
      );
      await _checkRunCompletion();
      notifyListeners();
      return;
    }

    // Resolve prompt template.
    final resolvedPrompt = _resolvePromptTemplate(node);

    // Determine working directory.
    final wd = node.workingDirectory ?? _workingDirectory;

    // Create session.
    final sessionId = await _sessionManager.createSession(
      name: '${def.name} / ${node.name}',
      cli: cli,
      workingDirectory: wd,
      input: resolvedPrompt,
      workflowRunId: run.id,
      workflowNodeId: node.id,
    );

    // Update node state.
    state.status = NodeStatus.running;
    state.sessionId = sessionId;
    state.startedAt = DateTime.now();
    run.nodeSessionIds[node.id] = sessionId;

    // Open terminal (spawns PTY).
    final session = await _db.getSession(sessionId);
    if (session != null) {
      await _terminals.open(session, cli);
    }

    _eventLog.log(
      ClusterEventKind.workflowNodeStarted,
      sessionName: '${def.name} / ${node.name}',
      detail: cli.displayName,
    );

    notifyListeners();
  }

  /// Handle a session exit event.
  void _onSessionExited(({int sessionId, int exitCode}) event) {
    final run = _currentRun;
    if (run == null || run.isFinished) return;

    // Find which node this session belongs to.
    String? nodeId;
    for (final entry in run.nodeSessionIds.entries) {
      if (entry.value == event.sessionId) {
        nodeId = entry.key;
        break;
      }
    }
    if (nodeId == null) return; // Not our session.

    final state = run.nodeRuns[nodeId]!;
    final now = DateTime.now();
    state.exitCode = event.exitCode;
    state.completedAt = now;

    if (event.exitCode == 0) {
      state.status = NodeStatus.completed;
    } else {
      state.status = NodeStatus.failed;
    }

    // Capture output for template resolution.
    _captureNodeOutput(nodeId);

    final def = _definition;
    _eventLog.log(
      state.status == NodeStatus.completed
          ? ClusterEventKind.workflowNodeCompleted
          : ClusterEventKind.workflowNodeFailed,
      sessionName: def != null
          ? '${def.name} / ${def.nodes.firstWhere((n) => n.id == nodeId).name}'
          : nodeId,
      detail: 'exit code ${event.exitCode}',
    );

    // Evaluate successors and check completion.
    _evaluateSuccessors(nodeId).then((_) {
      _checkRunCompletion();
      notifyListeners();
    });
  }

  /// Evaluate successors of a completed node.
  Future<void> _evaluateSuccessors(String completedNodeId) async {
    final run = _currentRun;
    final def = _definition;
    if (run == null || def == null) return;

    final outgoingEdges = _successors[completedNodeId] ?? [];
    final completedState = run.nodeRuns[completedNodeId]!;

    for (final edge in outgoingEdges) {
      final targetNodeId = edge.toNodeId;
      final targetState = run.nodeRuns[targetNodeId];
      if (targetState == null) continue;

      // Skip if already resolved.
      if (targetState.status.isTerminal) continue;

      // Check edge condition.
      final conditionMet = _isEdgeConditionSatisfied(
        edge,
        completedState.exitCode,
      );

      if (!conditionMet) {
        // This edge is not satisfied. Check if the target should be skipped
        // (all incoming edges evaluated and none satisfied).
        await _maybeSkipNode(targetNodeId);
        continue;
      }

      // Check if target is ready.
      final ready = _isNodeReady(targetNodeId);
      if (ready) {
        final targetNode = def.nodes.firstWhere((n) => n.id == targetNodeId);
        await _resolveNode(targetNode);
      }
    }
  }

  /// Check if an edge condition is satisfied given an exit code.
  bool _isEdgeConditionSatisfied(WorkflowEdge edge, int? exitCode) {
    switch (edge.condition) {
      case EdgeCondition.always:
        return true;
      case EdgeCondition.onSuccess:
        return exitCode == 0;
      case EdgeCondition.onFailure:
        return exitCode != null && exitCode != 0;
    }
  }

  /// Check if a node is ready to launch.
  ///
  /// - agentTask / join: ALL incoming edges must have their source resolved
  ///   AND each edge condition must be satisfied (AND semantics).
  /// - fork: ANY incoming edge with satisfied condition → ready (OR semantics).
  bool _isNodeReady(String nodeId) {
    final run = _currentRun;
    if (run == null) return false;

    final incomingEdges = _predecessors[nodeId] ?? [];
    if (incomingEdges.isEmpty) return true; // Root node.

    final def = _definition;
    if (def == null) return false;

    final targetNode = def.nodes.firstWhere((n) => n.id == nodeId);

    if (targetNode.type == WorkflowNodeType.fork) {
      // OR semantics: any incoming edge satisfied → ready.
      return incomingEdges.any((edge) {
        final sourceState = run.nodeRuns[edge.fromNodeId];
        if (sourceState == null || !sourceState.status.isTerminal) {
          return false;
        }
        return _isEdgeConditionSatisfied(edge, sourceState.exitCode);
      });
    } else {
      // AND semantics: all incoming edges must be resolved and satisfied.
      return incomingEdges.every((edge) {
        final sourceState = run.nodeRuns[edge.fromNodeId];
        if (sourceState == null || !sourceState.status.isTerminal) {
          return false;
        }
        return _isEdgeConditionSatisfied(edge, sourceState.exitCode);
      });
    }
  }

  /// Check if a node should be skipped (all incoming edges evaluated,
  /// none satisfied).
  Future<void> _maybeSkipNode(String nodeId) async {
    final run = _currentRun;
    final def = _definition;
    if (run == null || def == null) return;

    final state = run.nodeRuns[nodeId];
    if (state == null || state.status.isTerminal) return;

    final incomingEdges = _predecessors[nodeId] ?? [];
    if (incomingEdges.isEmpty) return;

    // Check if ALL sources are terminal.
    final allSourcesTerminal = incomingEdges.every((edge) {
      final sourceState = run.nodeRuns[edge.fromNodeId];
      return sourceState != null && sourceState.status.isTerminal;
    });

    if (!allSourcesTerminal) return;

    // Check if ANY edge condition is satisfied.
    final anySatisfied = incomingEdges.any((edge) {
      final sourceState = run.nodeRuns[edge.fromNodeId];
      if (sourceState == null) return false;
      return _isEdgeConditionSatisfied(edge, sourceState.exitCode);
    });

    if (anySatisfied) return; // Node will be launched by _isNodeReady check.

    // All sources terminal, no conditions satisfied → skip.
    state.status = NodeStatus.skipped;
    state.completedAt = DateTime.now();

    final node = def.nodes.firstWhere((n) => n.id == nodeId);
    _eventLog.log(
      ClusterEventKind.workflowNodeSkipped,
      sessionName: '${def.name} / ${node.name}',
      detail: 'No incoming conditions satisfied',
    );

    // Cascade: evaluate successors of this skipped node.
    // For skipped nodes, treat as if all outgoing edges with "always" condition
    // are satisfied (the skip cascades through "always" edges).
    await _evaluateSuccessorsAfterSkip(nodeId);
  }

  /// After a node is skipped, evaluate successors.
  /// Only "always" edges propagate through a skipped source.
  Future<void> _evaluateSuccessorsAfterSkip(String skippedNodeId) async {
    final run = _currentRun;
    final def = _definition;
    if (run == null || def == null) return;

    final outgoingEdges = _successors[skippedNodeId] ?? [];

    for (final edge in outgoingEdges) {
      final targetNodeId = edge.toNodeId;
      final targetState = run.nodeRuns[targetNodeId];
      if (targetState == null || targetState.status.isTerminal) continue;

      // For skipped sources, only "always" edges count.
      if (edge.condition != EdgeCondition.always) {
        await _maybeSkipNode(targetNodeId);
        continue;
      }

      final ready = _isNodeReady(targetNodeId);
      if (ready) {
        final targetNode = def.nodes.firstWhere((n) => n.id == targetNodeId);
        await _resolveNode(targetNode);
      } else {
        await _maybeSkipNode(targetNodeId);
      }
    }
  }

  /// Check if the entire run is complete.
  Future<void> _checkRunCompletion() async {
    final run = _currentRun;
    if (run == null || run.isFinished) return;

    final allTerminal = run.nodeRuns.values.every(
      (n) => n.status.isTerminal,
    );

    if (!allTerminal) return;

    // Determine final status.
    final hasFailed = run.nodeRuns.values.any(
      (n) => n.status == NodeStatus.failed,
    );

    final now = DateTime.now();
    run.completedAt = now;
    run.status = hasFailed
        ? WorkflowRunStatus.failed
        : WorkflowRunStatus.completed;

    await _db.updateWorkflowRunStatus(
      run.id,
      run.status.label,
      completedAt: now,
    );

    _exitSub?.cancel();
    _exitSub = null;

    _eventLog.log(
      hasFailed
          ? ClusterEventKind.workflowFailed
          : ClusterEventKind.workflowCompleted,
      sessionName: run.definitionName,
      detail: '${run.completedNodeCount}/${run.totalNodeCount} nodes',
    );
  }

  /// Capture output from a node's terminal for template resolution.
  void _captureNodeOutput(String nodeId) {
    final run = _currentRun;
    if (run == null) return;

    final state = run.nodeRuns[nodeId]!;
    if (state.sessionId == null) return;

    // Get output tail from the terminal controller.
    final def = _definition;
    final node = def?.nodes.firstWhere((n) => n.id == nodeId);
    final maxChars = node?.maxOutputChars ?? 3000;

    // Use getOutputTail which calls peekOutput (non-destructive).
    final output = _terminals.getOutputTail(
      state.sessionId!,
      maxLines: 200,
    );

    // Truncate to max chars.
    state.output = output.length > maxChars
        ? output.substring(output.length - maxChars)
        : output;
  }

  /// Resolve prompt template placeholders.
  String _resolvePromptTemplate(WorkflowNode node) {
    final template = node.promptTemplate;
    if (template == null || template.isEmpty) return '';

    final run = _currentRun;
    final def = _definition;
    if (run == null || def == null) return template;

    var resolved = template;

    // Replace {{node:<id>:<field>}} placeholders.
    final pattern = RegExp(r'\{\{node:([^:}]+):([^}]+)\}\}');
    resolved = resolved.replaceAllMapped(pattern, (match) {
      final refNodeId = match.group(1)!;
      final field = match.group(2)!;

      final refState = run.nodeRuns[refNodeId];
      if (refState == null) return '';

      final refNode = def.nodes.where((n) => n.id == refNodeId).firstOrNull;

      switch (field) {
        case 'output':
          final maxChars = refNode?.maxOutputChars ?? 3000;
          final output = refState.output ?? '';
          return output.length > maxChars
              ? output.substring(output.length - maxChars)
              : output;
        case 'input':
          // Get the original input for the referenced node's session.
          // We return a placeholder since we'd need to query the DB.
          return refState.output ?? '';
        case 'name':
          return refNode?.name ?? refNodeId;
        case 'status':
          return refState.status == NodeStatus.completed
              ? 'success'
              : refState.status.label;
        default:
          return match.group(0)!;
      }
    });

    // Replace {{workflow:<field>}} placeholders.
    resolved = resolved.replaceAll('{{workflow:name}}', def.name);
    resolved = resolved.replaceAll('{{workflow:id}}', run.id);

    return resolved;
  }

  /// Encode a workflow definition to JSON string for DB storage.
  String _encodeDefinitionJson(WorkflowDefinition definition) {
    try {
      return jsonEncode(definition.toJson());
    } catch (_) {
      return '{}';
    }
  }
}
