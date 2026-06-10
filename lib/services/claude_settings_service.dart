import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/claude_settings.dart';

/// Service for persisting Claude Code settings per CLI via SharedPreferences.
///
/// Settings are stored as JSON blobs keyed by CLI id (e.g. "claude"),
/// so multiple Claude-based CLIs can each have independent preferences.
class ClaudeSettingsService {
  ClaudeSettingsService._();

  static String _key(String cliId) => 'claude_settings_$cliId';

  /// Load saved settings for the given CLI id, or return defaults.
  static Future<ClaudeSettings> load(String cliId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cliId));
    if (raw == null || raw.isEmpty) return const ClaudeSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ClaudeSettings.fromJson(json);
    } catch (_) {
      return const ClaudeSettings();
    }
  }

  /// Persist settings for the given CLI id.
  static Future<void> save(String cliId, ClaudeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(settings.toJson());
    await prefs.setString(_key(cliId), raw);
  }
}
