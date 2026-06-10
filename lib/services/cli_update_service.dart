import 'dart:convert';
import 'dart:io';

import '../models/agent_cli.dart';

/// Checks npm and PyPI registries for latest versions of known CLIs.
///
/// Uses dart:io HttpClient directly — no extra dependency needed.
/// Results are purely in-memory (transient); call site should cache by session.
class CliUpdateService {
  static const Duration _timeout = Duration(seconds: 8);

  /// Check all detected CLIs for updates concurrently.
  /// Returns a map of cliId → latestVersion (null if check failed or N/A).
  static Future<Map<String, String>> checkAll(List<AgentCli> clis) async {
    final detectedWithPackages = clis.where(
      (c) => c.detected && (c.npmPackage != null || c.pipPackage != null),
    );

    final futures = detectedWithPackages.map((cli) async {
      final latest = await _fetchLatestVersion(cli);
      return MapEntry(cli.id, latest);
    });

    final entries = await Future.wait(futures);
    final result = <String, String>{};
    for (final e in entries) {
      if (e.value != null) result[e.key] = e.value!;
    }
    return result;
  }

  /// Fetch latest version for a single CLI from its registry.
  static Future<String?> _fetchLatestVersion(AgentCli cli) async {
    try {
      if (cli.npmPackage != null) {
        return await _fetchNpm(cli.npmPackage!);
      } else if (cli.pipPackage != null) {
        return await _fetchPypi(cli.pipPackage!);
      }
    } catch (_) {
      // Network errors are silently ignored
    }
    return null;
  }

  static Future<String?> _fetchNpm(String packageName) async {
    // Scoped packages: @scope/name → registry path is @scope%2Fname
    final encoded = Uri.encodeComponent(packageName);
    final uri = Uri.parse('https://registry.npmjs.org/$encoded/latest');
    final body = await _get(uri);
    if (body == null) return null;
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['version'] as String?;
  }

  static Future<String?> _fetchPypi(String packageName) async {
    final uri = Uri.parse('https://pypi.org/pypi/$packageName/json');
    final body = await _get(uri);
    if (body == null) return null;
    final json = jsonDecode(body) as Map<String, dynamic>;
    final info = json['info'] as Map<String, dynamic>?;
    return info?['version'] as String?;
  }

  static Future<String?> _get(Uri uri) async {
    final client = HttpClient();
    client.connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set('Accept', 'application/json');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) return null;
      return await response.transform(utf8.decoder).join().timeout(_timeout);
    } finally {
      client.close();
    }
  }

  /// Returns true if [latest] is strictly newer than [current].
  /// Uses semver-style numeric comparison (ignores pre-release tags).
  static bool isNewer(String current, String latest) {
    final c = _parseVersion(current);
    final l = _parseVersion(latest);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String v) {
    // Strip leading 'v', take only the numeric prefix (ignore -beta, +build)
    final clean = v.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[-+]')).first;
    final parts = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  /// Shell command to update a CLI via its package manager.
  static String updateCommand(AgentCli cli) {
    if (cli.npmPackage != null) {
      return 'npm install -g ${cli.npmPackage}';
    } else if (cli.pipPackage != null) {
      return 'pip install --upgrade ${cli.pipPackage}';
    }
    return '';
  }
}
