/// Status of a workflow run.
enum WorkflowRunStatus {
  running,
  completed,
  failed,
  cancelled;

  String get label => switch (this) {
        WorkflowRunStatus.running => 'running',
        WorkflowRunStatus.completed => 'completed',
        WorkflowRunStatus.failed => 'failed',
        WorkflowRunStatus.cancelled => 'cancelled',
      };
}

/// Status of an individual node within a workflow run.
enum NodeStatus {
  pending,
  waiting,
  running,
  completed,
  failed,
  skipped;

  bool get isTerminal =>
      this == completed ||
      this == failed ||
      this == skipped;

  String get label => switch (this) {
        NodeStatus.pending => 'pending',
        NodeStatus.waiting => 'waiting',
        NodeStatus.running => 'running',
        NodeStatus.completed => 'completed',
        NodeStatus.failed => 'failed',
        NodeStatus.skipped => 'skipped',
      };
}

/// Runtime state of a single node within a workflow run.
class NodeRunState {
  final String nodeId;
  NodeStatus status;
  int? sessionId;
  String? output;
  int? exitCode;
  DateTime? startedAt;
  DateTime? completedAt;

  NodeRunState({
    required this.nodeId,
    this.status = NodeStatus.pending,
    this.sessionId,
    this.output,
    this.exitCode,
    this.startedAt,
    this.completedAt,
  });

  /// Duration of this node's execution, or null if not started/completed.
  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }
}

/// Represents a single execution of a workflow definition.
class WorkflowRun {
  final String id;
  final String definitionId;
  final String definitionName;
  WorkflowRunStatus status;
  final Map<String, NodeRunState> nodeRuns;
  final Map<String, int> nodeSessionIds;
  final DateTime startedAt;
  DateTime? completedAt;

  WorkflowRun({
    required this.id,
    required this.definitionId,
    required this.definitionName,
    this.status = WorkflowRunStatus.running,
    Map<String, NodeRunState>? nodeRuns,
    Map<String, int>? nodeSessionIds,
    DateTime? startedAt,
    this.completedAt,
  })  : nodeRuns = nodeRuns ?? {},
        nodeSessionIds = nodeSessionIds ?? {},
        startedAt = startedAt ?? DateTime.now();

  /// Number of nodes in a terminal state.
  int get completedNodeCount =>
      nodeRuns.values.where((n) => n.status.isTerminal).length;

  /// Total number of nodes.
  int get totalNodeCount => nodeRuns.length;

  /// Whether all nodes have reached a terminal state.
  bool get isFinished =>
      status == WorkflowRunStatus.completed ||
      status == WorkflowRunStatus.failed ||
      status == WorkflowRunStatus.cancelled;
}
