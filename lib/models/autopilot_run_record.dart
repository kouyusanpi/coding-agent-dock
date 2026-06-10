class AutopilotRunRecord {
  final String id;
  final String goal;
  final String agentId;
  final String? workingDirectory;
  final int? sessionId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int iteration;
  final int totalSteps;
  final int doneSteps;
  final String? detail;

  const AutopilotRunRecord({
    required this.id,
    required this.goal,
    required this.agentId,
    required this.status,
    required this.startedAt,
    this.workingDirectory,
    this.sessionId,
    this.endedAt,
    this.iteration = 0,
    this.totalSteps = 0,
    this.doneSteps = 0,
    this.detail,
  });

  AutopilotRunRecord copyWith({
    String? id,
    String? goal,
    String? agentId,
    Object? workingDirectory = _sentinel,
    Object? sessionId = _sentinel,
    String? status,
    DateTime? startedAt,
    Object? endedAt = _sentinel,
    int? iteration,
    int? totalSteps,
    int? doneSteps,
    Object? detail = _sentinel,
  }) {
    return AutopilotRunRecord(
      id: id ?? this.id,
      goal: goal ?? this.goal,
      agentId: agentId ?? this.agentId,
      workingDirectory: identical(workingDirectory, _sentinel)
          ? this.workingDirectory
          : workingDirectory as String?,
      sessionId: identical(sessionId, _sentinel)
          ? this.sessionId
          : sessionId as int?,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: identical(endedAt, _sentinel)
          ? this.endedAt
          : endedAt as DateTime?,
      iteration: iteration ?? this.iteration,
      totalSteps: totalSteps ?? this.totalSteps,
      doneSteps: doneSteps ?? this.doneSteps,
      detail: identical(detail, _sentinel) ? this.detail : detail as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'agentId': agentId,
    'workingDirectory': workingDirectory,
    'sessionId': sessionId,
    'status': status,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'iteration': iteration,
    'totalSteps': totalSteps,
    'doneSteps': doneSteps,
    'detail': detail,
  };

  factory AutopilotRunRecord.fromJson(Map<String, dynamic> json) {
    return AutopilotRunRecord(
      id: json['id'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      agentId: json['agentId'] as String? ?? '',
      workingDirectory: json['workingDirectory'] as String?,
      sessionId: json['sessionId'] as int?,
      status: json['status'] as String? ?? 'failed',
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.tryParse(json['endedAt'] as String? ?? ''),
      iteration: json['iteration'] as int? ?? 0,
      totalSteps: json['totalSteps'] as int? ?? 0,
      doneSteps: json['doneSteps'] as int? ?? 0,
      detail: json['detail'] as String?,
    );
  }
}

const _sentinel = Object();
