import 'package:flutter/foundation.dart';

/// Category of a cluster event.
enum ClusterEventKind {
  sessionStarted,
  sessionCompleted,
  sessionFailed,
  sessionCancelled,
  ipcStop,
  ipcResult,
  ipcNotify,
  pipelineRelay,
  watchdogRetry,
  watchdogExhausted,
  memorySync,
  workflowStarted,
  workflowCompleted,
  workflowFailed,
  workflowCancelled,
  workflowNodeStarted,
  workflowNodeCompleted,
  workflowNodeFailed,
  workflowNodeSkipped,
}

/// One entry in the cluster event log.
class ClusterEvent {
  final ClusterEventKind kind;
  final DateTime timestamp;
  final String sessionName;
  final String? detail;

  const ClusterEvent({
    required this.kind,
    required this.timestamp,
    required this.sessionName,
    this.detail,
  });

  String get kindLabel => switch (kind) {
        ClusterEventKind.sessionStarted => 'started',
        ClusterEventKind.sessionCompleted => 'completed',
        ClusterEventKind.sessionFailed => 'failed',
        ClusterEventKind.sessionCancelled => 'cancelled',
        ClusterEventKind.ipcStop => 'IPC stop',
        ClusterEventKind.ipcResult => 'IPC result',
        ClusterEventKind.ipcNotify => 'IPC notify',
        ClusterEventKind.pipelineRelay => 'relayed',
        ClusterEventKind.watchdogRetry => 'watchdog retry',
        ClusterEventKind.watchdogExhausted => 'watchdog exhausted',
        ClusterEventKind.memorySync => 'memory sync',
        ClusterEventKind.workflowStarted => 'workflow started',
        ClusterEventKind.workflowCompleted => 'workflow completed',
        ClusterEventKind.workflowFailed => 'workflow failed',
        ClusterEventKind.workflowCancelled => 'workflow cancelled',
        ClusterEventKind.workflowNodeStarted => 'node started',
        ClusterEventKind.workflowNodeCompleted => 'node completed',
        ClusterEventKind.workflowNodeFailed => 'node failed',
        ClusterEventKind.workflowNodeSkipped => 'node skipped',
      };

  bool get isError =>
      kind == ClusterEventKind.sessionFailed ||
      kind == ClusterEventKind.watchdogExhausted ||
      kind == ClusterEventKind.workflowFailed ||
      kind == ClusterEventKind.workflowCancelled ||
      kind == ClusterEventKind.workflowNodeFailed;

  bool get isSuccess =>
      kind == ClusterEventKind.sessionCompleted ||
      kind == ClusterEventKind.ipcResult ||
      kind == ClusterEventKind.workflowCompleted ||
      kind == ClusterEventKind.workflowNodeCompleted;

  bool get isInfo => !isError && !isSuccess;
}

/// In-memory ring-buffer of recent cluster events.
///
/// Notifies listeners on change so the UI can rebuild reactively.
class EventLogService extends ChangeNotifier {
  static const _maxEntries = 200;

  final _events = <ClusterEvent>[];

  List<ClusterEvent> get events => List.unmodifiable(_events);

  /// Most recent [count] events, newest first.
  List<ClusterEvent> recent({int count = 50}) {
    final e = _events;
    if (e.length <= count) return List.unmodifiable(e.reversed.toList());
    return List.unmodifiable(
        e.sublist(e.length - count).reversed.toList());
  }

  void add(ClusterEvent event) {
    _events.add(event);
    if (_events.length > _maxEntries) {
      _events.removeAt(0);
    }
    notifyListeners();
  }

  void log(
    ClusterEventKind kind, {
    required String sessionName,
    String? detail,
  }) {
    add(ClusterEvent(
      kind: kind,
      timestamp: DateTime.now(),
      sessionName: sessionName,
      detail: detail,
    ));
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }

  int get count => _events.length;

  /// Number of error events.
  int get errorCount =>
      _events.where((e) => e.isError).length;
}
