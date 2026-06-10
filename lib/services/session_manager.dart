import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/agent_cli.dart';
import 'claude_settings_service.dart';

/// High-level service for managing session lifecycle.
///
/// Creates DB records and builds launch arguments for the in-app terminal
/// ([TerminalSessionsController] spawns the CLI in a PTY using these args).
///
/// For Claude Code, each session gets a generated UUID passed via
/// `--session-id` on first launch, and `--resume <uuid>` afterwards, so the
/// conversation is restored every time the session is reopened.
class SessionManager {
  static const _uuid = Uuid();

  final AppDatabase _db;

  SessionManager(this._db);

  /// Stream of all sessions from the database, newest first.
  ///
  /// Returns a **broadcast** stream so multiple widgets can subscribe
  /// simultaneously (e.g. TaskPanel body + stats header) without errors.
  Stream<List<TaskSession>> watchSessions() =>
      _db.watchAllSessions().asBroadcastStream();

  /// Stream of sessions filtered by agent CLI.
  Stream<List<TaskSession>> watchSessionsByCli(String cliId) {
    return _db.watchSessionsByCli(cliId);
  }

  /// Create a new session record in the database.
  ///
  /// For Claude Code, an agent session UUID is generated up-front so the
  /// session can always be resumed later with `--resume <uuid>`.
  Future<int> createSession({
    required String name,
    required AgentCli cli,
    String? workingDirectory,
    String? description,
    String? input,
    String? batchId,
    int? parentSessionId,
    String? workflowRunId,
    String? workflowNodeId,
    String? customArgs,
  }) async {
    final now = DateTime.now();
    return _db.createSession(TaskSessionsCompanion(
      name: Value(name),
      agentCliId: Value(cli.id),
      status: const Value('created'),
      workingDirectory: Value(workingDirectory),
      description: Value(description),
      input: Value(input),
      agentSessionId: Value(cli.id == 'claude' ? _uuid.v4() : null),
      batchId: Value(batchId),
      parentSessionId: Value(parentSessionId),
      workflowRunId: Value(workflowRunId),
      workflowNodeId: Value(workflowNodeId),
      customArgs: Value(customArgs),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Build the CLI argument list for launching [cli] in the terminal.
  ///
  /// [agentSessionId] — the stored agent session UUID (Claude only).
  /// [resume] — true when reopening a session that already ran; uses
  /// `--resume` instead of `--session-id` and omits the prompt.
  /// [prompt] — task prompt, appended as the positional argument.
  /// [workingDirectory] — the cwd the CLI will run in; used to verify a
  /// Claude session transcript actually exists before passing `--resume`.
  /// [customArgs] — user-entered launch-argument override. When non-null it
  /// replaces the agent's auto-generated flags (an empty string means "no extra
  /// flags"); Claude session-id/resume handling and the prompt are still added.
  /// [bare] — last-resort fallback: launch the bare command with no arguments
  /// at all (used after a launch died on an unknown-option error).
  Future<List<String>> buildLaunchArgs(
    AgentCli cli, {
    String? agentSessionId,
    bool resume = false,
    String? prompt,
    List<String> extraArgs = const [],
    String? workingDirectory,
    String? customArgs,
    bool bare = false,
    Set<String> deniedOptions = const {},
  }) async {
    // Bare relaunch: just the command, nothing else.
    if (bare) return <String>[];

    final args = <String>[];

    // A reopen only truly resumes when Claude actually persisted the session.
    // If the first launch failed before writing a transcript (e.g. it errored
    // out), `--resume <uuid>` would fail with "No session found" — so fall
    // back to `--session-id` to register the UUID fresh on this launch.
    var effectiveResume = resume;
    if (cli.id == 'claude' && resume && agentSessionId != null) {
      if (!claudeSessionExists(workingDirectory, agentSessionId)) {
        effectiveResume = false;
      }
    }

    if (cli.id == 'claude') {
      // Custom args override the auto-generated Claude settings flags.
      if (customArgs != null) {
        args.addAll(tokenizeArgs(customArgs));
      } else {
        final settings = await ClaudeSettingsService.load('claude');
        args.addAll(settings.toArgs());
      }
      if (agentSessionId != null && agentSessionId.isNotEmpty) {
        args.addAll(
          effectiveResume
              ? ['--resume', agentSessionId]
              : ['--session-id', agentSessionId],
        );
      }
    } else if (customArgs != null) {
      // Non-Claude CLIs carry no auto flags; custom args are their only flags.
      args.addAll(tokenizeArgs(customArgs));
    }

    args.addAll(extraArgs);

    // Drop any flags the CLI's installed version rejected previously (and their
    // trailing values). Done while `args` is still flags-only — before the
    // prompt is appended — so a value-less flag at the end can't swallow it.
    if (deniedOptions.isNotEmpty) {
      _removeOptions(args, deniedOptions);
    }

    final promptText = prompt?.trim() ?? '';

    // --print requires a prompt argument; remove it when launching an
    // interactive session with no initial prompt to avoid the
    // "Input must be provided … when using --print" error.
    if (promptText.isEmpty && !effectiveResume) {
      final pi = args.indexOf('--print');
      if (pi != -1) {
        args.removeAt(pi);
        final oi = args.indexOf('--output-format');
        if (oi != -1 && oi < args.length - 1) {
          args.removeAt(oi + 1); // value
          args.removeAt(oi);     // flag
        }
      }
    }

    if (!effectiveResume && promptText.isNotEmpty) {
      args.add(promptText);
    }
    return args;
  }

  /// Remove every option named in [denied] from a flags-only [args] list,
  /// along with one following value token (when the next token is not itself a
  /// flag). Mutates [args] in place.
  static void _removeOptions(List<String> args, Set<String> denied) {
    var i = 0;
    while (i < args.length) {
      if (denied.contains(args[i])) {
        args.removeAt(i); // the flag
        if (i < args.length && !args[i].startsWith('-')) {
          args.removeAt(i); // its value
        }
      } else {
        i++;
      }
    }
  }

  /// Split a raw launch-args string into tokens, honoring single/double quotes
  /// so values like `--append-system-prompt "be concise"` stay intact.
  /// Returns an empty list for blank input.
  static List<String> tokenizeArgs(String raw) {
    final tokens = <String>[];
    final buf = StringBuffer();
    var inToken = false;
    String? quote; // active quote char, or null

    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else {
          buf.write(c);
        }
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        inToken = true;
        continue;
      }
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        if (inToken) {
          tokens.add(buf.toString());
          buf.clear();
          inToken = false;
        }
        continue;
      }
      buf.write(c);
      inToken = true;
    }
    if (inToken) tokens.add(buf.toString());
    return tokens;
  }

  /// Predicate deciding whether a Claude session can be resumed. Defaults to a
  /// filesystem check ([_defaultClaudeSessionExists]); overridable in tests.
  bool Function(String? workingDirectory, String sessionId)
      claudeSessionExists = _defaultClaudeSessionExists;

  /// Whether Claude Code has a persisted transcript for [sessionId] under
  /// [workingDirectory]. Claude stores transcripts at
  /// `~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl`, where the cwd is
  /// encoded by replacing every non-alphanumeric character with `-`.
  static bool _defaultClaudeSessionExists(
      String? workingDirectory, String sessionId) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return false;
    final cwd =
        (workingDirectory != null && workingDirectory.trim().isNotEmpty)
            ? workingDirectory.trim()
            : home;
    final encoded = cwd.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
    final path = '$home/.claude/projects/$encoded/$sessionId.jsonl';
    return File(path).existsSync();
  }

  /// Mark a session as running (terminal opened).
  Future<void> markRunning(int sessionId) {
    return _db.updateSessionStatus(sessionId, 'running');
  }

  /// Persist the result when the terminal process exits.
  ///
  /// Saves the agent session id on every exit so the session can be
  /// resumed later, per the session lifecycle requirement.
  Future<void> markExited(
    int sessionId, {
    required int exitCode,
    int? durationMs,
    String? agentSessionId,
    bool cancelled = false,
    String? output,
  }) {
    final status = cancelled
        ? 'cancelled'
        : exitCode == 0
            ? 'completed'
            : 'failed';
    return _db.updateSessionStatus(
      sessionId,
      status,
      exitCode: exitCode,
      durationMs: durationMs,
      agentSessionId: agentSessionId,
      output: output,
    );
  }

  /// Generate and persist an agent session id for sessions that predate
  /// session-id tracking. Returns the new id.
  Future<String> assignAgentSessionId(int sessionId) async {
    final id = _uuid.v4();
    await _db.updateSessionStatus(sessionId, 'created', agentSessionId: id);
    return id;
  }

  /// Get a single session by id.
  Future<TaskSession?> getSession(int id) => _db.getSession(id);

  /// Delete all finished (completed/failed/cancelled) sessions.
  Future<int> clearFinishedSessions() => _db.deleteFinishedSessions();

  /// Return up to 10 recently used distinct input prompts.
  Future<List<String>> recentPrompts() => _db.recentPrompts();

  /// Return up to 5 recently used working directories (distinct, newest first).
  Future<List<String>> recentWorkingDirectories() =>
      _db.recentWorkingDirectories();

  /// Rename a session.
  Future<void> renameSession(int id, String name) => _db.renameSession(id, name);

  /// Delete a session record.
  Future<void> deleteSession(int id) => _db.deleteSession(id);
}
