/// Data model representing a detected AI programming agent CLI.
///
/// Serializable to JSON for local file cache.
class AgentCli {
  /// CLI identifier (e.g. "claude", "codex", "codewhale")
  final String id;

  /// Human-readable name (e.g. "Claude Code", "OpenAI Codex CLI", "CodeWhale")
  final String displayName;

  /// The primary binary name (e.g. "claude", "codex", "codewhale")
  final String binaryName;

  /// Alternative binary names to try
  final List<String> aliases;

  /// Version flag to use (e.g. "--version", "version", "-V")
  final String versionFlag;

  /// Whether the CLI was detected on this system
  final bool detected;

  /// Detected binary path (if found via which/where)
  final String? binaryPath;

  /// Detected version string (parsed from --version output)
  final String? version;

  /// Raw version output
  final String? versionRaw;

  /// Error message if detection failed
  final String? error;

  /// Timestamp of last detection attempt
  final DateTime lastChecked;

  /// Common install paths to check on macOS
  final List<String> commonPaths;

  /// Short install instructions shown when the CLI is not detected.
  final String? installHint;

  /// npm package name for update checks (e.g. "@anthropic-ai/claude-code")
  final String? npmPackage;

  /// pip/PyPI package name for update checks (e.g. "aider-chat")
  final String? pipPackage;

  /// Latest version fetched from the package registry (transient, not cached)
  final String? latestVersion;

  const AgentCli({
    required this.id,
    required this.displayName,
    required this.binaryName,
    this.aliases = const [],
    this.versionFlag = '--version',
    this.detected = false,
    this.binaryPath,
    this.version,
    this.versionRaw,
    this.error,
    required this.lastChecked,
    this.commonPaths = const [],
    this.installHint,
    this.npmPackage,
    this.pipPackage,
    this.latestVersion,
  });

  AgentCli copyWith({
    String? id,
    String? displayName,
    String? binaryName,
    List<String>? aliases,
    String? versionFlag,
    bool? detected,
    String? binaryPath,
    String? version,
    String? versionRaw,
    String? error,
    DateTime? lastChecked,
    List<String>? commonPaths,
    String? installHint,
    String? npmPackage,
    String? pipPackage,
    Object? latestVersion = _sentinel,
  }) {
    return AgentCli(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      binaryName: binaryName ?? this.binaryName,
      aliases: aliases ?? this.aliases,
      versionFlag: versionFlag ?? this.versionFlag,
      detected: detected ?? this.detected,
      binaryPath: binaryPath ?? this.binaryPath,
      version: version ?? this.version,
      versionRaw: versionRaw ?? this.versionRaw,
      error: error ?? this.error,
      lastChecked: lastChecked ?? this.lastChecked,
      commonPaths: commonPaths ?? this.commonPaths,
      installHint: installHint ?? this.installHint,
      npmPackage: npmPackage ?? this.npmPackage,
      pipPackage: pipPackage ?? this.pipPackage,
      latestVersion: latestVersion == _sentinel
          ? this.latestVersion
          : latestVersion as String?,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'binaryName': binaryName,
    'aliases': aliases,
    'versionFlag': versionFlag,
    'detected': detected,
    'binaryPath': binaryPath,
    'version': version,
    'versionRaw': versionRaw,
    'error': error,
    'lastChecked': lastChecked.toIso8601String(),
    'commonPaths': commonPaths,
  };

  factory AgentCli.fromJson(Map<String, dynamic> json) {
    return AgentCli(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      binaryName: json['binaryName'] as String,
      aliases: (json['aliases'] as List<dynamic>?)?.cast<String>() ?? [],
      versionFlag: json['versionFlag'] as String? ?? '--version',
      detected: json['detected'] as bool? ?? false,
      binaryPath: json['binaryPath'] as String?,
      version: json['version'] as String?,
      versionRaw: json['versionRaw'] as String?,
      error: json['error'] as String?,
      lastChecked: DateTime.parse(json['lastChecked'] as String),
      commonPaths: (json['commonPaths'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  String toString() => 'AgentCli($id, detected=$detected, version=$version)';
}
