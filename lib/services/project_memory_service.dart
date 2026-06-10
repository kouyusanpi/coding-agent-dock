import 'dart:io';

import 'package:path/path.dart' as p;

/// Shares one project-scoped memory file across every code agent that runs
/// in the same working directory.
///
/// The single source of truth is `<project>/.agentdock/shared-memory.md`.
/// Before a CLI launches, [syncForCli] copies that content into the agent's
/// *native* memory file (Claude → `CLAUDE.md`, Codex → `AGENTS.md`,
/// Gemini → `GEMINI.md`, …), wrapped in a marker-delimited managed block so
/// the agent picks it up automatically. Any user-authored content outside the
/// markers is preserved untouched.
///
/// All write logic is idempotent: re-syncing identical content is a no-op,
/// which makes it safe to call on every (concurrent) session launch.
class ProjectMemoryService {
  ProjectMemoryService._();

  static const startMarker =
      '<!-- AGENTDOCK:SHARED-MEMORY START — managed by AgentDock; '
      'edit .agentdock/shared-memory.md instead -->';
  static const endMarker = '<!-- AGENTDOCK:SHARED-MEMORY END -->';

  /// Project-root-relative path of the canonical shared memory file.
  static const sharedMemoryRelPath = '.agentdock/shared-memory.md';

  /// Native memory filename each agent CLI reads from its project root.
  /// CLIs absent from this map fall back to [defaultMemoryFileName].
  ///
  /// Values may include a subdirectory (e.g. Copilot's `.github/…`); the
  /// parent directory is created on write when necessary.
  static const memoryFileNames = <String, String>{
    'claude': 'CLAUDE.md',
    'codex': 'AGENTS.md',
    'gemini': 'GEMINI.md',
    'gh-copilot': '.github/copilot-instructions.md',
    'windsurf': '.windsurfrules',
    'goose': '.goosehints',
  };

  /// `AGENTS.md` is the emerging cross-tool convention; use it for any agent
  /// without a dedicated mapping.
  static const defaultMemoryFileName = 'AGENTS.md';

  /// The native memory filename for [cliId].
  static String memoryFileNameFor(String cliId) =>
      memoryFileNames[cliId] ?? defaultMemoryFileName;

  /// Absolute path to the shared memory file for [workingDirectory].
  static String sharedMemoryPath(String workingDirectory) =>
      p.join(workingDirectory, '.agentdock', 'shared-memory.md');

  /// Return [existing] with the managed shared-memory block set to [shared].
  ///
  /// Pure and immutable — returns a new string, never mutates [existing].
  /// Content outside the markers is preserved. When [shared] is blank, any
  /// existing managed block is removed (and the file otherwise left intact).
  static String injectSharedBlock(String existing, String shared) {
    final trimmedShared = shared.trim();
    if (trimmedShared.isEmpty) {
      return _stripBlock(existing);
    }

    final block = '$startMarker\n$trimmedShared\n$endMarker';
    final start = existing.indexOf(startMarker);
    final end = existing.indexOf(endMarker);

    if (start != -1 && end != -1 && end > start) {
      final before = existing.substring(0, start);
      final after = existing.substring(end + endMarker.length);
      return '$before$block$after';
    }

    if (existing.trim().isEmpty) {
      return '$block\n';
    }
    final base = existing.endsWith('\n') ? existing : '$existing\n';
    return '$base\n$block\n';
  }

  /// Sync the project's shared memory into [cliId]'s native memory file under
  /// [workingDirectory].
  ///
  /// No-op (returns false) when the working directory is blank, the shared
  /// memory file is missing or blank, or the native file already holds the
  /// identical block. Returns true when a file was written.
  static Future<bool> syncForCli({
    required String workingDirectory,
    required String cliId,
  }) async {
    final wd = workingDirectory.trim();
    if (wd.isEmpty) return false;

    final sharedFile = File(sharedMemoryPath(wd));
    if (!await sharedFile.exists()) return false;
    final shared = await sharedFile.readAsString();
    if (shared.trim().isEmpty) return false;

    final target = File(p.join(wd, memoryFileNameFor(cliId)));
    final existing = await target.exists() ? await target.readAsString() : '';
    final updated = injectSharedBlock(existing, shared);
    if (updated == existing) return false;

    // Create the parent dir for nested conventions (e.g. .github/…).
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    await target.writeAsString(updated);
    return true;
  }

  /// Read the project's shared memory file, or '' when it does not exist.
  static Future<String> readShared(String workingDirectory) async {
    final f = File(sharedMemoryPath(workingDirectory));
    return await f.exists() ? f.readAsString() : '';
  }

  /// Write the project's shared memory file (creating `.agentdock/` as needed),
  /// then refresh the managed block in any agent native files that already
  /// exist in the project — so an edit propagates immediately, without
  /// speculatively creating memory files for agents the project never uses.
  static Future<void> writeShared(
    String workingDirectory,
    String content,
  ) async {
    final wd = workingDirectory.trim();
    if (wd.isEmpty) return;
    final f = File(sharedMemoryPath(wd));
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
    await _refreshExistingNativeFiles(wd, content);
  }

  static Future<void> _refreshExistingNativeFiles(
    String workingDirectory,
    String shared,
  ) async {
    final names = <String>{defaultMemoryFileName, ...memoryFileNames.values};
    for (final name in names) {
      final target = File(p.join(workingDirectory, name));
      if (!await target.exists()) continue;
      final existing = await target.readAsString();
      final updated = injectSharedBlock(existing, shared);
      if (updated != existing) await target.writeAsString(updated);
    }
  }

  /// Remove the managed block from [content], tidying surrounding blank lines.
  static String _stripBlock(String content) {
    final start = content.indexOf(startMarker);
    final end = content.indexOf(endMarker);
    if (start == -1 || end == -1 || end < start) return content;

    final before = content.substring(0, start).trimRight();
    final after = content.substring(end + endMarker.length).trimLeft();
    if (before.isEmpty && after.isEmpty) return '';
    if (before.isEmpty) return '$after\n';
    if (after.isEmpty) return '$before\n';
    return '$before\n\n$after\n';
  }
}
