import 'package:uuid/uuid.dart';

/// Type of a node in a workflow DAG.
enum WorkflowNodeType {
  /// Runs a specific agent CLI with a prompt.
  agentTask,

  /// Virtual fan-out: resolves when ANY predecessor completes,
  /// fans out to all successors concurrently.
  fork,

  /// Virtual synchronization: resolves when ALL predecessors complete.
  join,
}

/// Condition on an edge between two workflow nodes.
enum EdgeCondition {
  /// Traverse regardless of predecessor outcome.
  always,

  /// Traverse only if predecessor exited 0.
  onSuccess,

  /// Traverse only if predecessor exited non-zero.
  onFailure,
}

/// A single node in a workflow DAG definition.
class WorkflowNode {
  final String id;
  final String name;
  final WorkflowNodeType type;

  /// Agent CLI id (e.g. "claude", "codex"). Required for [WorkflowNodeType.agentTask].
  final String? cliId;

  /// Prompt template with placeholders like `{{node:<id>:output}}`.
  /// Used for [WorkflowNodeType.agentTask] nodes.
  final String? promptTemplate;

  /// Override working directory for this node. Falls back to
  /// [WorkflowDefinition.defaultWorkingDirectory] if null.
  final String? workingDirectory;

  final String? description;

  /// How many chars of predecessor output to capture for template resolution.
  final int maxOutputChars;

  const WorkflowNode({
    required this.id,
    required this.name,
    required this.type,
    this.cliId,
    this.promptTemplate,
    this.workingDirectory,
    this.description,
    this.maxOutputChars = 3000,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (cliId != null) 'cliId': cliId,
        if (promptTemplate != null) 'promptTemplate': promptTemplate,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        if (description != null) 'description': description,
        'maxOutputChars': maxOutputChars,
      };

  factory WorkflowNode.fromJson(Map<String, dynamic> json) => WorkflowNode(
        id: json['id'] as String,
        name: json['name'] as String,
        type: WorkflowNodeType.values.byName(json['type'] as String),
        cliId: json['cliId'] as String?,
        promptTemplate: json['promptTemplate'] as String?,
        workingDirectory: json['workingDirectory'] as String?,
        description: json['description'] as String?,
        maxOutputChars: json['maxOutputChars'] as int? ?? 3000,
      );

  WorkflowNode copyWith({
    String? name,
    WorkflowNodeType? type,
    String? cliId,
    String? promptTemplate,
    String? workingDirectory,
    String? description,
    int? maxOutputChars,
  }) =>
      WorkflowNode(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        cliId: cliId ?? this.cliId,
        promptTemplate: promptTemplate ?? this.promptTemplate,
        workingDirectory: workingDirectory ?? this.workingDirectory,
        description: description ?? this.description,
        maxOutputChars: maxOutputChars ?? this.maxOutputChars,
      );
}

/// A directed edge between two workflow nodes.
class WorkflowEdge {
  final String fromNodeId;
  final String toNodeId;
  final EdgeCondition condition;

  const WorkflowEdge({
    required this.fromNodeId,
    required this.toNodeId,
    this.condition = EdgeCondition.always,
  });

  Map<String, dynamic> toJson() => {
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'condition': condition.name,
      };

  factory WorkflowEdge.fromJson(Map<String, dynamic> json) => WorkflowEdge(
        fromNodeId: json['fromNodeId'] as String,
        toNodeId: json['toNodeId'] as String,
        condition: EdgeCondition.values.byName(
          json['condition'] as String? ?? 'always',
        ),
      );

  WorkflowEdge copyWith({
    String? fromNodeId,
    String? toNodeId,
    EdgeCondition? condition,
  }) =>
      WorkflowEdge(
        fromNodeId: fromNodeId ?? this.fromNodeId,
        toNodeId: toNodeId ?? this.toNodeId,
        condition: condition ?? this.condition,
      );
}

/// A saved, reusable workflow blueprint (DAG of agent tasks).
///
/// Serializable to JSON for persistence and sharing.
class WorkflowDefinition {
  static const _uuid = Uuid();

  final String id;
  final String name;
  final String? description;
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final String? defaultWorkingDirectory;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkflowDefinition({
    required this.id,
    required this.name,
    this.description,
    required this.nodes,
    required this.edges,
    this.defaultWorkingDirectory,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new definition with an auto-generated id and timestamps.
  factory WorkflowDefinition.create({
    required String name,
    String? description,
    List<WorkflowNode> nodes = const [],
    List<WorkflowEdge> edges = const [],
    String? defaultWorkingDirectory,
  }) {
    final now = DateTime.now();
    return WorkflowDefinition(
      id: _uuid.v4(),
      name: name,
      description: description,
      nodes: nodes,
      edges: edges,
      defaultWorkingDirectory: defaultWorkingDirectory,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        if (defaultWorkingDirectory != null)
          'defaultWorkingDirectory': defaultWorkingDirectory,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorkflowDefinition.fromJson(Map<String, dynamic> json) =>
      WorkflowDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        nodes: (json['nodes'] as List<dynamic>)
            .map((e) => WorkflowNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        edges: (json['edges'] as List<dynamic>)
            .map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        defaultWorkingDirectory: json['defaultWorkingDirectory'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  WorkflowDefinition copyWith({
    String? name,
    String? description,
    List<WorkflowNode>? nodes,
    List<WorkflowEdge>? edges,
    String? defaultWorkingDirectory,
  }) =>
      WorkflowDefinition(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        nodes: nodes ?? this.nodes,
        edges: edges ?? this.edges,
        defaultWorkingDirectory:
            defaultWorkingDirectory ?? this.defaultWorkingDirectory,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// Validate the DAG structure. Returns a list of error messages.
  /// Empty list means the definition is valid.
  List<String> validate() {
    final errors = <String>[];
    final nodeIds = nodes.map((n) => n.id).toSet();

    // Check for duplicate node ids
    if (nodeIds.length != nodes.length) {
      errors.add('Duplicate node IDs detected');
    }

    // Check edge references
    for (final edge in edges) {
      if (!nodeIds.contains(edge.fromNodeId)) {
        errors.add(
          'Edge references unknown source node: ${edge.fromNodeId}',
        );
      }
      if (!nodeIds.contains(edge.toNodeId)) {
        errors.add(
          'Edge references unknown target node: ${edge.toNodeId}',
        );
      }
      if (edge.fromNodeId == edge.toNodeId) {
        errors.add('Self-loop detected on node: ${edge.fromNodeId}');
      }
    }

    // Check agent task nodes have cliId
    for (final node in nodes) {
      if (node.type == WorkflowNodeType.agentTask &&
          (node.cliId == null || node.cliId!.isEmpty)) {
        errors.add('Agent task node "${node.name}" has no CLI selected');
      }
    }

    // Check for orphan nodes (not reachable from any root)
    if (nodes.isNotEmpty) {
      final hasIncoming = <String>{};
      for (final edge in edges) {
        hasIncoming.add(edge.toNodeId);
      }
      final roots = nodeIds.difference(hasIncoming);
      if (roots.isEmpty && nodes.length > 1) {
        errors.add('No root nodes found (all nodes have incoming edges)');
      }

      // BFS reachability from roots
      final successors = <String, List<String>>{};
      for (final edge in edges) {
        successors.putIfAbsent(edge.fromNodeId, () => []).add(edge.toNodeId);
      }
      final reachable = <String>{};
      final queue = [...roots];
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        if (!reachable.add(current)) continue;
        for (final next in successors[current] ?? []) {
          if (!reachable.contains(next)) queue.add(next);
        }
      }
      final orphans = nodeIds.difference(reachable);
      if (orphans.isNotEmpty) {
        final orphanNames = nodes
            .where((n) => orphans.contains(n.id))
            .map((n) => n.name)
            .join(', ');
        errors.add('Unreachable nodes: $orphanNames');
      }
    }

    // Cycle detection using Kahn's algorithm
    if (nodes.isNotEmpty && edges.isNotEmpty) {
      final inDegree = <String, int>{};
      for (final node in nodes) {
        inDegree[node.id] = 0;
      }
      for (final edge in edges) {
        if (nodeIds.contains(edge.toNodeId)) {
          inDegree[edge.toNodeId] = (inDegree[edge.toNodeId] ?? 0) + 1;
        }
      }

      final queue = <String>[
        for (final entry in inDegree.entries)
          if (entry.value == 0) entry.key,
      ];
      var sorted = 0;
      final adj = <String, List<String>>{};
      for (final edge in edges) {
        adj.putIfAbsent(edge.fromNodeId, () => []).add(edge.toNodeId);
      }

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        sorted++;
        for (final next in adj[current] ?? []) {
          inDegree[next] = (inDegree[next] ?? 0) - 1;
          if (inDegree[next] == 0) queue.add(next);
        }
      }

      if (sorted != nodes.length) {
        errors.add('Cycle detected in workflow graph');
      }
    }

    return errors;
  }
}
