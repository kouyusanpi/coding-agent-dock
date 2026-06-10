import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/agent_cli.dart';

/// Service for caching CLI detection results as a JSON file.
///
/// This is the "lightweight" storage tier: simple config/cache data
/// that doesn't need SQL queries. The JSON file lives in the app's
/// support directory alongside the Drift database.
class CliCacheService {
  CliCacheService._();

  static const _fileName = 'cli_cache.json';

  /// Get the full path to the cache file.
  static Future<String> _getCachePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, _fileName);
  }

  /// Load cached CLI results from disk.
  static Future<List<AgentCli>?> load() async {
    try {
      final path = await _getCachePath();
      final file = File(path);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList
          .map((e) => AgentCli.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  /// Save CLI results to disk.
  static Future<void> save(List<AgentCli> clis) async {
    try {
      final path = await _getCachePath();
      final file = File(path);

      // Ensure directory exists
      await Directory(p.dirname(path)).create(recursive: true);

      final jsonList = clis.map((c) => c.toJson()).toList();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonList),
        flush: true,
      );
    } catch (e) {
      // Silently fail — cache is not critical
    }
  }

  /// Clear the cache file.
  static Future<void> clear() async {
    try {
      final path = await _getCachePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
