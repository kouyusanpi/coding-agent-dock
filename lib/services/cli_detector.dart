import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/agent_cli.dart';
import 'settings_service.dart';

/// Service that detects locally installed AI agent CLIs.
///
/// Detection strategy (macOS):
/// 1. Optional user-supplied path override (Settings).
/// 2. Check [AgentCli.commonPaths] in order — a fast, no-spawn shortcut.
/// 3. Search the user's REAL login-shell `$PATH` (resolved once via
///    `$SHELL -ilc 'echo $PATH'`, cached). A GUI-launched macOS app inherits a
///    minimal PATH that omits nvm/homebrew/custom dirs, so this is what makes
///    detection flexible — it finds the binary wherever `which`/`where` would,
///    including e.g. `~/.nvm/versions/node/<v>/bin/claude`. If a binary isn't
///    on this PATH (and not in commonPaths), it is genuinely not installed.
/// 4. Run `<binaryPath> <versionFlag>` to verify it's functional + get version.
/// 5. Parse version from output with a heuristic regex.
class CliDetector {
  CliDetector._();

  /// Cached login-shell PATH directories (resolved lazily, once per run).
  static List<String>? _cachedPathDirs;

  /// Detect a single CLI. Returns an updated [AgentCli] with detection results.
  static Future<AgentCli> detect(AgentCli cli) async {
    // Step 1: Locate the binary
    final path = await _findBinary(cli);
    if (path == null) {
      return cli.copyWith(
        detected: false,
        error: 'Binary not found: ${cli.binaryName}',
        lastChecked: DateTime.now(),
      );
    }

    // Step 2: Verify by running version command
    try {
      final result = await _runVersionCommand(path, cli.versionFlag);

      if (result.exitCode == 0 && result.stdout.isNotEmpty) {
        final version = _parseVersion(result.stdout);
        return cli.copyWith(
          detected: true,
          binaryPath: path,
          version: version,
          versionRaw: result.stdout.trim(),
          lastChecked: DateTime.now(),
          error: null,
        );
      } else {
        final errorOutput = result.stderr.isNotEmpty
            ? result.stderr.trim()
            : result.stdout.trim();
        return cli.copyWith(
          detected: true, // binary exists, but version check had issues
          binaryPath: path,
          version: null,
          versionRaw: result.stdout.trim().isNotEmpty ? result.stdout.trim() : null,
          error: errorOutput.isNotEmpty ? errorOutput : 'Exit code ${result.exitCode}',
          lastChecked: DateTime.now(),
        );
      }
    } catch (e) {
      return cli.copyWith(
        detected: true, // binary exists
        binaryPath: path,
        version: null,
        error: 'Version check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Detect all CLIs in the registry concurrently, with bounded parallelism.
  ///
  /// At most [concurrency] CLI processes run at the same time to avoid
  /// overwhelming the system when the registry is large. [onUpdate] fires for
  /// each result as it arrives — callers use this for live-progressive rendering.
  /// The returned list preserves registry order.
  static Future<List<AgentCli>> detectAll(
    List<AgentCli> registry, {
    void Function(AgentCli result)? onUpdate,
    int concurrency = 4,
  }) async {
    final semaphore = _Semaphore(concurrency);
    final futures = registry.map((cli) async {
      await semaphore.acquire();
      try {
        final result = await detect(cli);
        onUpdate?.call(result);
        return result;
      } finally {
        semaphore.release();
      }
    });
    return Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Locate a binary: user override → commonPaths → the user's login-shell
  /// `$PATH`. The PATH search is what makes this flexible — it resolves the
  /// binary wherever the user's shell `which`/`where` would, with no hardcoded
  /// list. Returns null only when the binary is truly absent everywhere.
  static Future<String?> _findBinary(AgentCli cli) async {
    final homeDir = Platform.environment['HOME'] ?? '';

    // Step 0: User-supplied path override (Settings → Claude CLI path).
    if (cli.id == 'claude') {
      final override = SettingsService.claudeCliPath;
      if (override != null && override.isNotEmpty) {
        final resolved = override.replaceAll(r'$HOME', homeDir);
        if (await _isExecutable(resolved)) return resolved;
      }
    }

    // Step 1: Known install paths — fast, no process spawn.
    for (final commonPath in cli.commonPaths) {
      final resolved = commonPath.replaceAll(r'$HOME', homeDir);
      if (await _isExecutable(resolved)) return resolved;
    }

    // Step 2: Search the user's real login-shell PATH (nvm, homebrew, custom
    // installs the GUI app's PATH doesn't include). This is the `which`/`where`
    // equivalent — if it's not here, it's not installed.
    final pathDirs = await _loginShellPathDirs();
    for (final name in [cli.binaryName, ...cli.aliases]) {
      for (final dir in pathDirs) {
        final candidate = p.join(dir, name);
        if (await _isExecutable(candidate)) return candidate;
      }
    }

    return null;
  }

  /// The directories on the user's login-shell `$PATH`, resolved once and
  /// cached. Runs `$SHELL -ilc 'echo $PATH'` so that interactive rc files
  /// (`~/.zshrc`, nvm/homebrew shims, etc.) are sourced — a GUI-launched app
  /// otherwise sees only a stripped-down PATH. The process's own PATH is
  /// appended as a fallback, and duplicates are removed while preserving order.
  static Future<List<String>> _loginShellPathDirs() async {
    if (_cachedPathDirs != null) return _cachedPathDirs!;

    final dirs = <String>[];
    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    try {
      final result = await Process.run(shell, ['-ilc', r'echo "$PATH"'])
          .timeout(const Duration(seconds: 8));
      if (result.exitCode == 0) {
        dirs.addAll((result.stdout as String)
            .trim()
            .split(':')
            .where((d) => d.isNotEmpty));
      }
    } catch (_) {
      // Shell unavailable / sandboxed — fall back to the process PATH below.
    }

    // Always include the process PATH as a backstop.
    dirs.addAll(
        (Platform.environment['PATH'] ?? '').split(':').where((d) => d.isNotEmpty));

    // De-duplicate, preserving first-seen order (PATH precedence).
    final seen = <String>{};
    final deduped = [for (final d in dirs) if (seen.add(d)) d];
    _cachedPathDirs = deduped;
    return deduped;
  }

  /// Clear the cached login-shell PATH so the next detection re-resolves it
  /// (e.g. after the user installs a CLI into a brand-new directory).
  static void clearPathCache() => _cachedPathDirs = null;

  /// Check if a path points to an executable file.
  static Future<bool> _isExecutable(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final file = File(path);
      final exists = await file.exists();
      if (!exists) return false;
      // On macOS/Linux, check if executable bit is set
      final stat = await file.stat();
      // Check if the mode has any execute bit
      final mode = stat.mode;
      // 0x49 = S_IXUSR | S_IXGRP | S_IXOTH (00111 in octal → 0x49 in decimal? No, need to check)
      // Actually, let's be more precise: S_IXUSR = 0x40, S_IXGRP = 0x08, S_IXOTH = 0x01
      return (mode & 0x49) != 0;
    } catch (_) {
      return false;
    }
  }

  /// Run the version command on a binary, timing out after [timeout].
  ///
  /// A frozen or network-stalling CLI would otherwise block the entire
  /// detection batch. On timeout we return a synthetic ProcessResult (exit
  /// code 124, the GNU `timeout` convention) so the caller treats the binary
  /// as present-but-broken rather than missing.
  static Future<ProcessResult> _runVersionCommand(
    String path,
    String versionFlag, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final args = versionFlag.split(' ');
    return Process.run(path, args).timeout(
      timeout,
      onTimeout: () =>
          ProcessResult(-1, 124, '', 'Version check timed out after ${timeout.inSeconds}s'),
    );
  }

  static String? _parseVersion(String output) {
    // Pattern for semantic version: optional 'v' + digits.digits.digits + optional suffix
    final versionPattern = RegExp(
      r'(?:v)?\d+\.\d+\.\d+(?:[-\w.]*)?',
      caseSensitive: false,
    );
    final match = versionPattern.firstMatch(output);
    if (match != null) {
      return match.group(0);
    }

    // Fallback: try to extract any version-like line
    final lines = output.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().contains('version')) {
        // Return the whole line as version
        if (trimmed.length > 100) {
          return '${trimmed.substring(0, 100)}...';
        }
        return trimmed;
      }
    }

    return null;
  }
}

/// Bounded counting semaphore — limits concurrent async operations.
class _Semaphore {
  int _count;
  final Queue<Completer<void>> _waiters = Queue();

  _Semaphore(int max) : _count = max;

  Future<void> acquire() {
    if (_count > 0) {
      _count--;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _count++;
    }
  }
}
