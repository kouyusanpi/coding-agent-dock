/// A persistent rule: when [sourceAgentId] finishes, automatically relay to [targetAgentId].
class PipelineRule {
  final String id;
  final String sourceAgentId;
  final String targetAgentId;
  /// If true, relay only on success (exit 0 or IPC stop event).
  /// If false, relay regardless of exit code.
  final bool onSuccessOnly;
  final bool enabled;

  const PipelineRule({
    required this.id,
    required this.sourceAgentId,
    required this.targetAgentId,
    this.onSuccessOnly = true,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceAgentId': sourceAgentId,
        'targetAgentId': targetAgentId,
        'onSuccessOnly': onSuccessOnly,
        'enabled': enabled,
      };

  factory PipelineRule.fromJson(Map<String, dynamic> json) => PipelineRule(
        id: json['id'] as String,
        sourceAgentId: json['sourceAgentId'] as String,
        targetAgentId: json['targetAgentId'] as String,
        onSuccessOnly: json['onSuccessOnly'] as bool? ?? true,
        enabled: json['enabled'] as bool? ?? true,
      );

  PipelineRule copyWith({
    String? sourceAgentId,
    String? targetAgentId,
    bool? onSuccessOnly,
    bool? enabled,
  }) =>
      PipelineRule(
        id: id,
        sourceAgentId: sourceAgentId ?? this.sourceAgentId,
        targetAgentId: targetAgentId ?? this.targetAgentId,
        onSuccessOnly: onSuccessOnly ?? this.onSuccessOnly,
        enabled: enabled ?? this.enabled,
      );
}
