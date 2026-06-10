/// Settings model for Claude Code CLI — discovered at runtime from `claude --help`.
///
/// All options map directly to CLI flags. Defaults are the CLI defaults.
class ClaudeSettings {
  /// Model alias (e.g. "sonnet", "opus") or full API name.
  final String model;

  /// Thinking effort level.
  final ClaudeEffort effort;

  /// Agent for the session (overrides configured agent).
  final String? agent;

  /// Permission mode.
  final ClaudePermissionMode permissionMode;

  /// Whether to enable the dangerously-skip-permissions bypass.
  final bool dangerouslySkipPermissions;

  /// Whether to run in non-interactive print mode (-p / --print).
  final bool printMode;

  /// Output format for print mode.
  final ClaudeOutputFormat outputFormat;

  /// Additional CLI flags to pass (raw).
  final List<String> extraFlags;

  const ClaudeSettings({
    this.model = 'opus',
    this.effort = ClaudeEffort.high,
    this.agent,
    this.permissionMode = ClaudePermissionMode.defaultMode,
    this.dangerouslySkipPermissions = false,
    this.printMode = false,
    this.outputFormat = ClaudeOutputFormat.text,
    this.extraFlags = const [],
  });

  /// Build CLI arguments for `claude` command.
  List<String> toArgs() {
    final args = <String>[];
    args.addAll(['--model', model]);
    args.addAll(['--effort', effort.cliValue]);
    if (agent != null) args.addAll(['--agent', agent!]);
    if (permissionMode != ClaudePermissionMode.defaultMode) {
      args.addAll(['--permission-mode', permissionMode.cliValue]);
    }
    if (dangerouslySkipPermissions) {
      args.add('--dangerously-skip-permissions');
    }
    if (printMode) {
      args.add('--print');
      args.addAll(['--output-format', outputFormat.cliValue]);
    }
    args.addAll(extraFlags);
    return args;
  }

  ClaudeSettings copyWith({
    String? model,
    ClaudeEffort? effort,
    String? agent,
    ClaudePermissionMode? permissionMode,
    bool? dangerouslySkipPermissions,
    bool? printMode,
    ClaudeOutputFormat? outputFormat,
    List<String>? extraFlags,
  }) {
    return ClaudeSettings(
      model: model ?? this.model,
      effort: effort ?? this.effort,
      agent: agent ?? this.agent,
      permissionMode: permissionMode ?? this.permissionMode,
      dangerouslySkipPermissions:
          dangerouslySkipPermissions ?? this.dangerouslySkipPermissions,
      printMode: printMode ?? this.printMode,
      outputFormat: outputFormat ?? this.outputFormat,
      extraFlags: extraFlags ?? this.extraFlags,
    );
  }

  Map<String, dynamic> toJson() => {
    'model': model,
    'effort': effort.cliValue,
    'agent': agent,
    'permissionMode': permissionMode.cliValue,
    'dangerouslySkipPermissions': dangerouslySkipPermissions,
    'printMode': printMode,
    'outputFormat': outputFormat.cliValue,
    'extraFlags': extraFlags,
  };

  factory ClaudeSettings.fromJson(Map<String, dynamic> json) {
    return ClaudeSettings(
      model: json['model'] as String? ?? 'opus',
      effort: ClaudeEffort.from(json['effort'] as String?),
      agent: json['agent'] as String?,
      permissionMode:
          ClaudePermissionMode.from(json['permissionMode'] as String?),
      dangerouslySkipPermissions:
          json['dangerouslySkipPermissions'] as bool? ?? false,
      printMode: json['printMode'] as bool? ?? false,
      outputFormat: ClaudeOutputFormat.from(json['outputFormat'] as String?),
      extraFlags:
          (json['extraFlags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Thinking effort levels for Claude Code (--effort flag).
enum ClaudeEffort {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  xhigh('xhigh', 'Extra High'),
  max('max', 'Maximum');

  final String cliValue;
  final String label;
  const ClaudeEffort(this.cliValue, this.label);

  static ClaudeEffort from(String? value) {
    return ClaudeEffort.values.firstWhere(
      (e) => e.cliValue == value,
      orElse: () => ClaudeEffort.high,
    );
  }
}

/// Permission modes for Claude Code (--permission-mode flag).
enum ClaudePermissionMode {
  defaultMode('default', 'Default'),
  acceptEdits('acceptEdits', 'Accept Edits'),
  auto('auto', 'Auto'),
  bypassPermissions('bypassPermissions', 'Bypass All'),
  dontAsk('dontAsk', "Don't Ask"),
  plan('plan', 'Plan Only');

  final String cliValue;
  final String label;
  const ClaudePermissionMode(this.cliValue, this.label);

  static ClaudePermissionMode from(String? value) {
    return ClaudePermissionMode.values.firstWhere(
      (e) => e.cliValue == value,
      orElse: () => ClaudePermissionMode.defaultMode,
    );
  }
}

/// Output format for print mode (--output-format flag).
enum ClaudeOutputFormat {
  text('text', 'Plain Text'),
  json('json', 'JSON'),
  streamJson('stream-json', 'Stream JSON');

  final String cliValue;
  final String label;
  const ClaudeOutputFormat(this.cliValue, this.label);

  static ClaudeOutputFormat from(String? value) {
    return ClaudeOutputFormat.values.firstWhere(
      (e) => e.cliValue == value,
      orElse: () => ClaudeOutputFormat.text,
    );
  }
}
