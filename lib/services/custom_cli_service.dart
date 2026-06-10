import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_cli.dart';

/// Persists user-added custom agent CLI definitions.
///
/// Stored in SharedPreferences as a JSON list under [_key]. Custom agents
/// are merged with the built-in [CliRegistry] entries on every scan, and
/// participate in the same detection flow (which / commonPaths / version).
class CustomCliService {
  CustomCliService._();

  static const _key = 'custom_agent_clis';

  /// Prefix for custom agent ids — guarantees no clash with built-ins
  /// and lets the UI distinguish removable agents.
  static const idPrefix = 'custom_';

  // Not cached: SharedPreferences.getInstance() is already a cheap singleton,
  // and caching here breaks test isolation (setMockInitialValues creates a
  // fresh instance that a static cache would never see).
  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  /// Whether [cli] is a user-added custom agent.
  static bool isCustom(AgentCli cli) => cli.id.startsWith(idPrefix);

  /// Load all custom agent definitions (undetected templates).
  static Future<List<AgentCli>> load() async {
    try {
      final raw = (await _p).getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AgentCli.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<AgentCli> clis) async {
    final jsonList = clis.map((c) => c.toJson()).toList();
    await (await _p).setString(_key, jsonEncode(jsonList));
  }

  /// Create and persist a new custom agent definition.
  ///
  /// [binary] may be a bare command name (resolved via `which`) or an
  /// absolute path (used directly as a commonPath).
  /// Returns the created [AgentCli], or null when a custom agent with the
  /// same binary already exists.
  static Future<AgentCli?> add({
    required String displayName,
    required String binary,
    String versionFlag = '--version',
  }) async {
    final name = displayName.trim();
    final bin = binary.trim();
    if (name.isEmpty || bin.isEmpty) return null;

    final existing = await load();
    final isPath = bin.contains('/');
    final binaryName = isPath ? bin.split('/').last : bin;

    final duplicate = existing.any((c) =>
        c.binaryName == binaryName ||
        (isPath && c.commonPaths.contains(bin)));
    if (duplicate) return null;

    final cli = AgentCli(
      id: '$idPrefix${DateTime.now().microsecondsSinceEpoch}',
      displayName: name,
      binaryName: binaryName,
      versionFlag: versionFlag.trim().isEmpty ? '--version' : versionFlag.trim(),
      lastChecked: DateTime.now(),
      commonPaths: isPath ? [bin] : const [],
    );

    await _save([...existing, cli]);
    return cli;
  }

  /// Remove a custom agent definition by id. No-op for built-in ids.
  static Future<void> remove(String id) async {
    if (!id.startsWith(idPrefix)) return;
    final existing = await load();
    await _save(existing.where((c) => c.id != id).toList());
  }
}
