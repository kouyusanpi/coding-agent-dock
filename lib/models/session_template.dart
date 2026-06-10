/// A saved session template for quick task launch.
class SessionTemplate {
  final String id;
  final String name;
  final String agentId;
  final String? workingDirectory;
  final String prompt;
  final DateTime createdAt;

  const SessionTemplate({
    required this.id,
    required this.name,
    required this.agentId,
    this.workingDirectory,
    required this.prompt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agentId': agentId,
        'workingDirectory': workingDirectory,
        'prompt': prompt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SessionTemplate.fromJson(Map<String, dynamic> json) =>
      SessionTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        agentId: json['agentId'] as String,
        workingDirectory: json['workingDirectory'] as String?,
        prompt: json['prompt'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  SessionTemplate copyWith({
    String? name,
    String? agentId,
    String? workingDirectory,
    String? prompt,
  }) =>
      SessionTemplate(
        id: id,
        name: name ?? this.name,
        agentId: agentId ?? this.agentId,
        workingDirectory: workingDirectory ?? this.workingDirectory,
        prompt: prompt ?? this.prompt,
        createdAt: createdAt,
      );
}
