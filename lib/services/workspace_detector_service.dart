import 'dart:convert';
import 'dart:io';

/// A workspace suggestion from auto-detection.
class WorkspaceSuggestion {
  final String path;
  final String source; // e.g. 'Finder', 'Cursor', 'VS Code'

  const WorkspaceSuggestion({required this.path, required this.source});
}

/// Detects likely project directories from the local macOS environment:
///   1. Frontmost Finder window
///   2. Recently opened workspaces from Cursor / VS Code / Windsurf / VSCodium
class WorkspaceDetectorService {
  static const _ideConfigs = [
    (name: 'Cursor', support: 'Cursor'),
    (name: 'VS Code', support: 'Code'),
    (name: 'Windsurf', support: 'Windsurf'),
    (name: 'VSCodium', support: 'VSCodium'),
  ];

  /// Returns up to [maxPerSource] suggestions per source, deduplicated.
  static Future<List<WorkspaceSuggestion>> detect({int maxPerSource = 5}) async {
    final results = <WorkspaceSuggestion>[];
    final seen = <String>{};

    void add(String path, String source) {
      if (seen.add(path)) {
        results.add(WorkspaceSuggestion(path: path, source: source));
      }
    }

    // 1. Frontmost Finder window
    final finderPath = await _frontFinderWindow();
    if (finderPath != null) add(finderPath, 'Finder');

    // 2. IDE recent workspaces (Cursor, VS Code, Windsurf, VSCodium)
    final home = Platform.environment['HOME'] ?? '';
    for (final ide in _ideConfigs) {
      final dbPath =
          '$home/Library/Application Support/${ide.support}/User/globalStorage/state.vscdb';
      if (!File(dbPath).existsSync()) continue;
      try {
        final paths = await _recentWorkspacesFromDb(dbPath);
        var count = 0;
        for (final p in paths) {
          if (count >= maxPerSource) break;
          if (Directory(p).existsSync()) {
            add(p, ide.name);
            count++;
          }
        }
      } catch (_) {}
    }

    return results;
  }

  static Future<String?> _frontFinderWindow() async {
    try {
      final r = await Process.run('osascript', [
        '-e',
        'tell application "Finder" to if (count of windows) > 0 then '
            'return POSIX path of (target of front window as alias)',
      ]).timeout(const Duration(seconds: 3));
      final p = r.stdout.toString().trim().replaceAll('\n', '');
      if (p.isNotEmpty && Directory(p).existsSync()) return p;
    } catch (_) {}
    return null;
  }

  static Future<List<String>> _recentWorkspacesFromDb(String dbPath) async {
    try {
      final r = await Process.run('sqlite3', [
        '-readonly',
        dbPath,
        "SELECT value FROM ItemTable WHERE key = 'history.recentlyOpenedPathsList'",
      ]).timeout(const Duration(seconds: 3));

      if (r.exitCode != 0) return [];
      final raw = r.stdout.toString().trim();
      if (raw.isEmpty) return [];

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (data['entries'] as List?) ?? [];
      final paths = <String>[];
      for (final e in entries) {
        final uri = (e['folderUri'] as String?) ??
            ((e['workspace'] as Map?)?['configPath'] as String?);
        if (uri == null || !uri.startsWith('file://')) continue;
        // Decode percent-encoding and strip the 'file://' prefix
        final path = Uri.decodeFull(uri.substring(7));
        paths.add(path);
      }
      return paths;
    } catch (_) {
      return [];
    }
  }
}
