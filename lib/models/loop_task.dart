import 'dart:convert';

/// A saved loop-task configuration that can be re-run on demand.
///
/// A loop task runs the same [prompt] against the same [agentId] for
/// [loopCount] iterations (parallel sessions), each with an incrementing
/// name suffix (e.g. "Refactor #1", "Refactor #2").
class LoopTask {
  final String id;
  final String name;
  final String agentId;
  final String prompt;
  final int loopCount;
  final String? workingDirectory;

  const LoopTask({
    required this.id,
    required this.name,
    required this.agentId,
    required this.prompt,
    required this.loopCount,
    this.workingDirectory,
  });

  LoopTask copyWith({
    String? name,
    String? agentId,
    String? prompt,
    int? loopCount,
    Object? workingDirectory = _sentinel,
  }) =>
      LoopTask(
        id: id,
        name: name ?? this.name,
        agentId: agentId ?? this.agentId,
        prompt: prompt ?? this.prompt,
        loopCount: loopCount ?? this.loopCount,
        workingDirectory: workingDirectory == _sentinel
            ? this.workingDirectory
            : workingDirectory as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agentId': agentId,
        'prompt': prompt,
        'loopCount': loopCount,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
      };

  factory LoopTask.fromJson(Map<String, dynamic> json) => LoopTask(
        id: json['id'] as String,
        name: json['name'] as String,
        agentId: json['agentId'] as String,
        prompt: json['prompt'] as String,
        loopCount: (json['loopCount'] as num).toInt(),
        workingDirectory: json['workingDirectory'] as String?,
      );

  String encode() => jsonEncode(toJson());

  static LoopTask? tryDecode(String raw) {
    try {
      return LoopTask.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

// Sentinel for copyWith optional nullable field.
const _sentinel = Object();
