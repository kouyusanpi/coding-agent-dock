import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import '../database/database.dart';
import '../models/agent_cli.dart';
import '../utils/ansi_utils.dart';
import 'attachment_service.dart';
import 'notification_service.dart';
import 'process_monitor_service.dart';
import 'project_memory_service.dart';
import 'session_manager.dart';
import 'settings_service.dart';

/// One live in-app terminal bound to a task session.
///
/// The [terminal] buffer keeps accumulating PTY output even while the tab is
/// not visible, so switching tasks never loses output.
class ActiveTerminal {
  final int sessionId;
  final String sessionName;
  final AgentCli cli;
  final Terminal terminal;
  final TerminalController viewController;

  Pty? pty;
  String? agentSessionId;
  bool hasLaunchedBefore;
  bool closing = false;
  int? exitCode;
  DateTime? startedAt;

  /// Effective working directory used when the PTY was last launched.
  String? workingDirectory;

  /// True when the current launch passed `--resume` (Claude). Lets [_onExit]
  /// recover from a stale/missing session by relaunching fresh.
  bool launchedWithResume = false;

  /// True once a resume failure has triggered a one-shot fresh relaunch, so we
  /// never retry-loop.
  bool resumeFallbackTried = false;

  /// Set when PTY output matches a known "session cannot be resumed" error.
  bool resumeErrorSeen = false;

  /// True when the current launch passed at least one extra flag (anything
  /// beyond the bare command). Gates the unknown-option → bare relaunch.
  bool launchedWithArgs = false;

  /// True once a bad-argument failure has triggered the one-shot bare relaunch,
  /// so we never retry-loop.
  bool bareFallbackTried = false;

  /// Set when PTY output matches a known "unknown/invalid option" error.
  bool argErrorSeen = false;

  /// The specific option the CLI rejected on this launch (parsed from the error
  /// text), or null when it couldn't be pinpointed. Drives precise flag removal.
  String? rejectedOption;

  /// Options this CLI's version has rejected, accumulated across relaunches and
  /// seeded from persisted per-CLI state. Stripped from every launch up-front.
  final Set<String> deniedOptions = <String>{};

  /// Pending attachment file paths (pasted/dropped/picked images & files).
  /// Shown as a thumbnail strip; auto-injected into the prompt on Enter.
  final List<String> attachments = [];

  /// True when this terminal produced output while it was NOT the active
  /// tab — surfaces as an unread dot; cleared when the tab is focused.
  bool hasUnread = false;

  // Raw PTY output accumulator — stripped of ANSI on exit, then saved
  // to the DB output column so sessions can be relayed to other agents.
  // Capped at ~300 KB raw; older data is dropped from the front.
  final StringBuffer _outputBuffer = StringBuffer();
  final StreamController<String> _outputBroadcast =
      StreamController.broadcast();

  /// Stream of raw PTY output data — used by SSE subscribers in [IpcServer].
  Stream<String> get rawOutputStream => _outputBroadcast.stream;

  static const int _outputCapBytes = 300 * 1024;
  static const int _outputTrimBytes = 200 * 1024;

  void _appendOutput(String data) {
    _outputBuffer.write(data);
    if (!_outputBroadcast.isClosed) _outputBroadcast.add(data);
    if (_outputBuffer.length > _outputCapBytes) {
      final s = _outputBuffer.toString();
      _outputBuffer
        ..clear()
        ..write(s.substring(s.length - _outputTrimBytes));
    }
  }

  void closeOutputStream() {
    if (!_outputBroadcast.isClosed) _outputBroadcast.close();
  }

  /// Return the accumulated output, stripping ANSI and trimming to 8 KB.
  /// Clears the buffer.
  String flushOutput() {
    final raw = _outputBuffer.toString();
    _outputBuffer.clear();
    if (raw.isEmpty) return '';
    return AnsiUtils.tail(AnsiUtils.stripAnsi(raw), maxChars: 8000);
  }

  /// Cleaned plain-text snapshot of recent output for LLM context — strips
  /// ANSI and TUI chrome and collapses full-screen repaint duplicates so a
  /// supervising LLM sees the agent's real output, not box-border noise.
  String contextSnapshot({int maxLines = 120}) =>
      AnsiUtils.cleanForContext(_outputBuffer.toString(), maxLines: maxLines);

  /// Return the last [maxLines] non-empty lines of the output buffer without
  /// flushing it. Used for live output tails in the cluster comparison dialog.
  String peekOutput({int maxLines = 5}) {
    final raw = _outputBuffer.toString();
    if (raw.isEmpty) return '';
    final clean = AnsiUtils.stripAnsi(raw);
    final lines = clean.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final tail = lines.length > maxLines
        ? lines.sublist(lines.length - maxLines)
        : lines;
    return tail.join('\n');
  }

  ActiveTerminal({
    required this.sessionId,
    required this.sessionName,
    required this.cli,
    required this.agentSessionId,
    required this.hasLaunchedBefore,
  }) : terminal = Terminal(maxLines: 10000),
       viewController = TerminalController();

  bool get running => pty != null;

  /// Write [text] into the running CLI's stdin (no-op when exited).
  /// Used for image-path paste, drag-and-drop and file attachments.
  void sendText(String text) {
    pty?.write(const Utf8Encoder().convert(text));
  }

  /// Effective status for the task panel while this terminal is open.
  String get effectiveStatus {
    if (running) return 'running';
    if (exitCode == null) return 'created';
    return exitCode == 0 ? 'completed' : 'failed';
  }
}

/// Holds every open in-app terminal so multiple tasks — across multiple
/// agents — run concurrently. The UI renders only the active one; background
/// terminals keep their PTYs alive and their buffers updated.
///
/// Claude session resume contract: first launch passes `--session-id <uuid>`,
/// every relaunch passes `--resume <uuid>`, and the id is persisted to the
/// database on every PTY exit.
class TerminalSessionsController extends ChangeNotifier {
  final SessionManager sessionManager;

  final Map<int, ActiveTerminal> _terminals = <int, ActiveTerminal>{};
  // Tracks display order independently so tabs can be reordered.
  final List<int> _order = [];
  int? _activeId;

  final StreamController<({int sessionId, int exitCode})> _exitController =
      StreamController.broadcast();

  /// Fires once for each PTY exit — after the session record is persisted.
  /// Consumers (e.g. HomeScreen auto-relay) subscribe to act on completion.
  Stream<({int sessionId, int exitCode})> get exitEvents =>
      _exitController.stream;

  /// IPC server port to inject into every PTY as AGENTDOCK_IPC_URL.
  /// Set by HomeScreen after the IPC server starts.
  int? ipcPort;

  /// Path to the generated shell helpers script (`~/.agentdock/helpers.sh`).
  /// Injected as AGENTDOCK_HELPERS into every PTY so agents can source it.
  String helpersScriptPath = '';

  /// Called after a live shared-memory re-sync completes. Receives the
  /// session name and agent display name so callers can log the event.
  void Function(String sessionName, String agentName)? onMemorySynced;

  Timer? _memorySyncTimer;

  /// Latest CPU + RSS stats per running session, updated by [updateProcessStats].
  ///
  /// Home screen polls [ProcessMonitorService] every ~3 s and writes here.
  /// Callers read via [statsOf]; writes call [notifyListeners] so the task panel
  /// picks up fresh values without a separate subscription.
  Map<int, ProcessStats> _processStats = {};

  /// Return the latest [ProcessStats] for [sessionId], or null when unavailable.
  ProcessStats? statsOf(int sessionId) => _processStats[sessionId];

  /// Replace the full stats snapshot and notify listeners so the UI refreshes.
  void updateProcessStats(Map<int, ProcessStats> stats) {
    _processStats = stats;
    notifyListeners();
  }

  /// Last-seen modification time of each project's shared-memory file, keyed by
  /// working directory. Lets [_pollSharedMemory] skip directories whose shared
  /// memory hasn't changed instead of re-reading/writing native files.
  final Map<String, DateTime> _lastSharedMtime = {};

  /// Lower-case substrings that indicate a `--resume` launch could not find or
  /// restore the requested session. Matched against stripped PTY output.
  static const _resumeFailureMarkers = <String>[
    'no conversation found',
    'no session found',
    'no deferred tool marker',
    'could not find session',
    'session not found',
    'no such session',
  ];

  /// A resume launch is considered failed if it exits non-zero within this
  /// window — a healthy resume opens an interactive session and stays running.
  static const _resumeQuickFailWindow = Duration(seconds: 8);

  /// Lower-case substrings that indicate the CLI rejected a launch argument
  /// (e.g. an `--effort` flag an older version doesn't support). Matched
  /// against stripped PTY output so a bad-args launch can fall back to bare.
  static const _argErrorMarkers = <String>[
    'unknown option',
    'unknown argument',
    'unknown flag',
    'unknown command',
    'unrecognized option',
    'unrecognized argument',
    'invalid option',
    'invalid argument',
    'unexpected argument',
    'unexpected option',
    "error: option",
    'too many arguments',
  ];

  /// Whether [output] (a chunk of PTY text) signals that a `--resume` launch
  /// could not restore the session. Pure; matched case-insensitively.
  @visibleForTesting
  static bool looksLikeResumeFailure(String output) {
    final lower = output.toLowerCase();
    return _resumeFailureMarkers.any(lower.contains);
  }

  /// Whether [output] signals that the CLI rejected one of the launch
  /// arguments. Pure; matched case-insensitively.
  @visibleForTesting
  static bool looksLikeArgError(String output) {
    final lower = output.toLowerCase();
    return _argErrorMarkers.any(lower.contains);
  }

  /// Matches a rejected option name out of an unknown-option error message,
  /// e.g. `error: unknown option '--effort'` → `--effort`. Commander.js (used
  /// by Claude Code) and most getopt-style CLIs quote the flag right after the
  /// marker word. Returns null when no flag token can be pinpointed.
  static final RegExp _rejectedOptionPattern = RegExp(
    r"(?:unknown|unrecognized|invalid|unexpected)\s+(?:option|flag|argument)"
    r"""[:\s]+['"]?(--?[A-Za-z0-9][\w-]*)""",
    caseSensitive: false,
  );

  /// Extract the specific option the CLI rejected from [output], or null if it
  /// can't be pinpointed (caller then falls back to a bare relaunch). Pure.
  @visibleForTesting
  static String? extractRejectedOption(String output) {
    final m = _rejectedOptionPattern.firstMatch(output);
    return m?.group(1);
  }

  TerminalSessionsController(this.sessionManager) {
    _memorySyncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollSharedMemory(),
    );
  }

  /// Poll running terminals — if their project's shared memory file changed,
  /// re-sync it into each CLI's native memory file.
  ///
  /// Terminals are grouped by working directory and the shared file's mtime is
  /// checked once per directory; unchanged directories are skipped entirely, so
  /// the steady-state cost is one `stat()` per active project per tick.
  Future<void> _pollSharedMemory() async {
    final byDir = <String, List<ActiveTerminal>>{};
    for (final term in _terminals.values) {
      if (!term.running) continue;
      final wd = term.workingDirectory;
      if (wd == null || wd.isEmpty) continue;
      byDir.putIfAbsent(wd, () => []).add(term);
    }

    for (final entry in byDir.entries) {
      final wd = entry.key;
      DateTime mtime;
      try {
        final stat = await File(
          ProjectMemoryService.sharedMemoryPath(wd),
        ).stat();
        if (stat.type == FileSystemEntityType.notFound) {
          _lastSharedMtime.remove(wd);
          continue;
        }
        mtime = stat.modified;
      } catch (_) {
        continue;
      }

      final last = _lastSharedMtime[wd];
      if (last != null && !mtime.isAfter(last)) continue; // unchanged
      _lastSharedMtime[wd] = mtime;

      for (final term in entry.value) {
        try {
          final synced = await ProjectMemoryService.syncForCli(
            workingDirectory: wd,
            cliId: term.cli.id,
          );
          if (synced) {
            onMemorySynced?.call(term.sessionName, term.cli.displayName);
          }
        } catch (_) {
          // Non-critical.
        }
      }
    }
  }

  List<ActiveTerminal> get openTerminals =>
      List.unmodifiable(_order.map((id) => _terminals[id]!));

  /// Reorder tabs: move from [oldIndex] to [newIndex] (same semantics as
  /// [ReorderableListView] — the new index is before the removal).
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;
    final id = _order.removeAt(oldIndex);
    _order.insert(newIndex, id);
    notifyListeners();
  }

  ActiveTerminal? get active =>
      _activeId == null ? null : _terminals[_activeId];

  int? get activeId => _activeId;

  bool isOpen(int sessionId) => _terminals.containsKey(sessionId);

  /// Live status override for the task panel; null when not open here.
  String? statusOf(int sessionId) => _terminals[sessionId]?.effectiveStatus;

  /// The open terminal for [sessionId], or null if not open.
  ActiveTerminal? terminalOf(int sessionId) => _terminals[sessionId];

  /// Live raw output stream for SSE subscribers; null when session not open.
  Stream<String>? outputStreamOf(int sessionId) =>
      _terminals[sessionId]?.rawOutputStream;

  /// Open (or focus) the terminal for [session]. Launches the CLI on first
  /// open; reopening an already-open tab just switches to it.
  Future<void> open(TaskSession session, AgentCli cli) async {
    final existing = _terminals[session.id];
    if (existing != null) {
      _activeId = session.id;
      existing.hasUnread = false;
      notifyListeners();
      return;
    }

    final term = ActiveTerminal(
      sessionId: session.id,
      sessionName: session.name,
      cli: cli,
      agentSessionId: session.agentSessionId,
      // 'created' means this session never ran — start fresh with the
      // prompt; anything else resumes the existing conversation.
      hasLaunchedBefore: session.status != 'created',
    );
    _terminals[session.id] = term;
    _order.add(session.id);
    _activeId = session.id;
    notifyListeners();

    await _launch(term, prompt: session.input);
  }

  void setActive(int sessionId) {
    if (!_terminals.containsKey(sessionId) || _activeId == sessionId) return;
    _activeId = sessionId;
    _terminals[sessionId]!.hasUnread = false;
    notifyListeners();
  }

  /// Unread-output flag for the task panel; false when not open here.
  bool hasUnread(int sessionId) => _terminals[sessionId]?.hasUnread ?? false;

  /// Return the last [maxLines] non-empty lines of live PTY output for a
  /// session without flushing the buffer. Used by the cluster live-output view.
  String getOutputTail(int sessionId, {int maxLines = 5}) =>
      _terminals[sessionId]?.peekOutput(maxLines: maxLines) ?? '';

  /// Cleaned LLM-context snapshot of a session's output (see
  /// [ActiveTerminal.contextSnapshot]). Used by the Autopilot to feed the
  /// supervising LLM real agent output instead of TUI repaint noise.
  String getAgentContext(int sessionId, {int maxLines = 120}) =>
      _terminals[sessionId]?.contextSnapshot(maxLines: maxLines) ?? '';

  /// Terminals whose CLI process is currently running.
  List<ActiveTerminal> get runningTerminals =>
      _order.map((id) => _terminals[id]!).where((t) => t.running).toList();

  /// Map of session ID → PTY PID for all currently-running sessions.
  /// Used by [ProcessMonitorService] to sample CPU/memory.
  Map<int, int> get sessionPids {
    final map = <int, int>{};
    for (final entry in _terminals.entries) {
      final pid = entry.value.pty?.pid;
      if (pid != null) map[entry.key] = pid;
    }
    return map;
  }

  /// Send [text] (followed by Enter) to every running terminal at once —
  /// the "ask all agents the same thing" collaboration primitive.
  /// Returns the number of terminals the message was sent to.
  int broadcast(String text) {
    final targets = runningTerminals;
    for (final term in targets) {
      term.sendText('$text\n');
    }
    return targets.length;
  }

  /// Send [text] (followed by Enter) to a single session's PTY stdin.
  /// No-op if the session has no active running terminal.
  /// Returns 1 if sent, 0 otherwise.
  int sendToSession(int sessionId, String text) {
    final term = _terminals[sessionId];
    if (term == null || !term.running) return 0;
    term.sendText('$text\n');
    return 1;
  }

  /// Type [text] into a session's prompt, then submit it with Enter.
  ///
  /// The Enter is a carriage return (`\r`) — the canonical Enter keystroke
  /// Ink/React TUIs (Claude Code, CodeWhale, …) submit on (`\n` is treated as a
  /// newline inside the box, leaving instructions unsent and piling up). It is
  /// sent as a SEPARATE write after a short delay: these TUIs ingest the
  /// injected text as a paste and only submit on a later, standalone Enter — a
  /// back-to-back `\r` gets absorbed into the paste and the line sits unsent.
  /// Used by the Autopilot to drive agents. Returns 1 if the text was written.
  int submitToSession(int sessionId, String text) {
    final term = _terminals[sessionId];
    if (term == null || !term.running) return 0;
    term.sendText(text);
    Timer(_submitEnterDelay, () {
      final t = _terminals[sessionId];
      if (t != null && t.running) t.sendText('\r');
    });
    return 1;
  }

  /// Delay between typing injected text and pressing Enter — lets the TUI
  /// render the pasted input before the standalone submit keystroke arrives.
  static const _submitEnterDelay = Duration(milliseconds: 180);

  /// Send [raw] bytes straight to a session's PTY stdin with NO trailing Enter.
  /// Used by the Autopilot to send single keystrokes (Enter, Space, arrows,
  /// Ctrl-combos) when answering an agent's interactive prompt/menu.
  /// Returns true if written, false when the session has no running terminal.
  bool sendRawToSession(int sessionId, String raw) {
    final term = _terminals[sessionId];
    if (term == null || !term.running) return false;
    term.sendText(raw);
    return true;
  }

  // --- Attachments (image paste / drag-drop / file picker) ---

  /// Queue attachment paths on a session; shown in the thumbnail strip and
  /// auto-injected into the prompt when the user presses Enter.
  void addAttachments(int sessionId, Iterable<String> paths) {
    final term = _terminals[sessionId];
    if (term == null) return;
    final list = paths.where((p) => p.isNotEmpty).toList();
    if (list.isEmpty) return;
    term.attachments.addAll(list);
    notifyListeners();
  }

  void removeAttachmentAt(int sessionId, int index) {
    final term = _terminals[sessionId];
    if (term == null || index < 0 || index >= term.attachments.length) return;
    term.attachments.removeAt(index);
    notifyListeners();
  }

  void clearAttachments(int sessionId) {
    final term = _terminals[sessionId];
    if (term == null || term.attachments.isEmpty) return;
    term.attachments.clear();
    notifyListeners();
  }

  /// Type all queued attachment paths into the CLI's input line right now
  /// (without sending), then clear the queue.
  void insertAttachmentsNow(int sessionId) {
    final term = _terminals[sessionId];
    if (term == null || !term.running || term.attachments.isEmpty) return;
    term.sendText(AttachmentService.formatPaths(term.attachments));
    term.attachments.clear();
    notifyListeners();
  }

  /// Relaunch the CLI for an exited terminal (resumes the conversation).
  Future<void> relaunch(int sessionId) async {
    final term = _terminals[sessionId];
    if (term == null || term.running) return;
    await _launch(term, prompt: null);
  }

  /// Close a tab: kill its PTY (exit persists as cancelled) and remove it.
  Future<void> close(int sessionId) async {
    final term = _terminals.remove(sessionId);
    if (term == null) return;
    _order.remove(sessionId);
    term.closing = true;
    term.closeOutputStream();
    term.pty?.kill();
    if (_activeId == sessionId) {
      _activeId = _order.isEmpty ? null : _order.last;
    }
    notifyListeners();
  }

  Future<void> _launch(
    ActiveTerminal term, {
    String? prompt,
    bool bare = false,
  }) async {
    final cli = term.cli;
    if (cli.binaryPath == null) {
      term.terminal.write(
        'CLI ${cli.displayName} not found. Run Scan to detect it.\r\n',
      );
      return;
    }

    // Older records may predate session-id tracking — assign one now.
    if (cli.id == 'claude' &&
        (term.agentSessionId == null || term.agentSessionId!.isEmpty)) {
      term.agentSessionId = await sessionManager.assignAgentSessionId(
        term.sessionId,
      );
      term.hasLaunchedBefore = false;
    }

    final session = await sessionManager.getSession(term.sessionId);
    final resolvedWd = _workingDirectory(session?.workingDirectory);
    final projectDir = session?.workingDirectory?.trim();
    term.workingDirectory = projectDir != null && projectDir.isNotEmpty
        ? projectDir
        : null;

    // Seed denied options from persisted per-CLI state so flags this version is
    // already known to reject are stripped up-front (no fail-then-retry churn).
    term.deniedOptions.addAll(SettingsService.deniedFlagsFor(cli.id));

    final args = await sessionManager.buildLaunchArgs(
      cli,
      agentSessionId: term.agentSessionId,
      resume: term.hasLaunchedBefore,
      prompt: prompt,
      workingDirectory: resolvedWd,
      customArgs: session?.customArgs,
      bare: bare,
      deniedOptions: term.deniedOptions,
    );

    // Track whether this launch actually resumed, so a stale-session failure
    // can be recovered by relaunching fresh (see [_onExit]).
    term.launchedWithResume = args.contains('--resume');
    term.resumeErrorSeen = false;
    // Track whether any extra flags were passed, so an unknown-option failure
    // can be recovered by relaunching with the bare command (see [_onExit]).
    term.launchedWithArgs = args.any((a) => a.startsWith('-'));
    term.argErrorSeen = false;
    term.rejectedOption = null;

    await sessionManager.markRunning(term.sessionId);

    final env = Map<String, String>.from(Platform.environment);
    env['TERM'] = 'xterm-256color';
    // Keep Claude Code in the MAIN screen buffer: in alternate-screen mode
    // xterm has no scrollback, so history above the viewport is invisible.
    // With this set, output flows into the 10k-line scrollback like a
    // regular terminal. (Ignored by other CLIs.)
    env['CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN'] = '1';
    // IPC backchannel — lets agent CLIs (and Claude Code hooks) POST structured
    // events back to AgentDock without writing to stdout.
    if (ipcPort != null) {
      final sessionId = term.sessionId;
      env['AGENTDOCK_IPC_URL'] =
          'http://127.0.0.1:$ipcPort/v1/sessions/$sessionId/events';
      env['AGENTDOCK_SESSION_ID'] = '$sessionId';
      env['AGENTDOCK_PORT'] = '$ipcPort';
      // Cluster API: GET /v1/sessions (discovery) + POST /v1/sessions/:id/inject
      env['AGENTDOCK_API_BASE'] = 'http://127.0.0.1:$ipcPort/v1';
      // Shell helpers: source "$AGENTDOCK_HELPERS" to get agentdock_* functions.
      env['AGENTDOCK_HELPERS'] = helpersScriptPath;
    }

    // Share project-scoped memory across every agent in this directory by
    // syncing .agentdock/shared-memory.md into the CLI's native memory file.
    // Guard on an explicit project dir — never touch the $HOME fallback.
    if (term.workingDirectory != null) {
      try {
        await ProjectMemoryService.syncForCli(
          workingDirectory: term.workingDirectory!,
          cliId: cli.id,
        );
      } catch (_) {
        // Non-critical: a memory-sync failure must not block the session.
      }
    }

    final pty = Pty.start(
      cli.binaryPath!,
      arguments: args,
      workingDirectory: resolvedWd,
      environment: env,
      columns: term.terminal.viewWidth,
      rows: term.terminal.viewHeight,
    );

    pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((data) {
          term.terminal.write(data);
          term._appendOutput(data);
          // Detect a "cannot resume this session" error so [_onExit] can recover.
          if (term.launchedWithResume &&
              !term.resumeErrorSeen &&
              looksLikeResumeFailure(data)) {
            term.resumeErrorSeen = true;
          }
          // Detect a rejected launch argument (e.g. an unsupported `--effort`) so
          // [_onExit] can strip just that flag (or fall back to the bare command).
          if (term.launchedWithArgs &&
              !term.argErrorSeen &&
              looksLikeArgError(data)) {
            term.argErrorSeen = true;
            term.rejectedOption = extractRejectedOption(data);
          }
          // Background output → unread dot (only notify on the transition).
          if (_activeId != term.sessionId && !term.closing && !term.hasUnread) {
            term.hasUnread = true;
            notifyListeners();
          }
        });

    term.terminal.onOutput = (data) {
      // When attachments are queued, inject their paths right before the
      // Enter that sends the message, so the CLI receives "<text> <paths>".
      if (data == '\r' && term.attachments.isNotEmpty) {
        pty.write(utf8.encode(AttachmentService.formatPaths(term.attachments)));
        term.attachments.clear();
        notifyListeners();
      }
      pty.write(utf8.encode(data));
    };
    term.terminal.onResize = (w, h, pw, ph) => pty.resize(h, w);

    pty.exitCode.then((code) => _onExit(term, code));

    term.pty = pty;
    term.exitCode = null;
    term.startedAt = DateTime.now();
    notifyListeners();
  }

  String _workingDirectory(String? dir) {
    if (dir != null && dir.trim().isNotEmpty) return dir.trim();
    return Platform.environment['HOME'] ?? '/';
  }

  Future<void> _onExit(ActiveTerminal term, int code) async {
    final durationMs = term.startedAt == null
        ? null
        : DateTime.now().difference(term.startedAt!).inMilliseconds;

    final quickFail =
        code != 0 &&
        durationMs != null &&
        durationMs < _resumeQuickFailWindow.inMilliseconds;

    // Recover from a rejected launch argument: if the CLI printed an
    // unknown/invalid-option error (e.g. an `--effort` flag its version doesn't
    // support). Checked before the resume fallback because the marker is
    // specific — a bad flag would otherwise masquerade as a quick-fail and
    // waste a resume retry.
    if (!term.closing && term.launchedWithArgs && term.argErrorSeen) {
      final opt = term.rejectedOption;

      // Preferred path: we pinpointed the offending flag — strip just that one
      // (keeping the user's other valid flags) and relaunch. Persist it so it's
      // dropped up-front from now on. Capped + dedup-guarded against looping.
      if (opt != null &&
          !term.deniedOptions.contains(opt) &&
          term.deniedOptions.length < 16) {
        term.deniedOptions.add(opt);
        await SettingsService.addDeniedFlag(term.cli.id, opt);
        term.flushOutput(); // discard the failed attempt's output
        term.pty = null;
        term.terminal.write(
          '\r\n\x1b[33m[AgentDock] 不支持的启动参数 $opt — 已移除并重新启动…\x1b[0m\r\n',
        );
        final session = await sessionManager.getSession(term.sessionId);
        await _launch(
          term,
          prompt: term.launchedWithResume ? null : session?.input,
        );
        return;
      }

      // Couldn't pinpoint the flag (or stripping didn't converge) — last resort:
      // relaunch once with the bare command and no arguments at all.
      if (!term.bareFallbackTried) {
        term.bareFallbackTried = true;
        term.flushOutput();
        term.pty = null;
        term.terminal.write(
          '\r\n\x1b[33m[AgentDock] 启动参数被拒绝（unknown option）— '
          '改用无参数命令重新启动…\x1b[0m\r\n',
        );
        await _launch(term, prompt: null, bare: true);
        return;
      }
    }

    // Recover from a stale/unresumable session: if a `--resume` launch failed
    // (matched error text, or exited non-zero almost immediately), relaunch
    // once with a fresh session id and no `--resume`. The old conversation is
    // gone either way, so re-run the original task rather than leaving a dead
    // tab. Guarded by [resumeFallbackTried] so it never loops.
    if (!term.closing &&
        term.launchedWithResume &&
        !term.resumeFallbackTried &&
        (term.resumeErrorSeen || quickFail)) {
      term.resumeFallbackTried = true;
      term.flushOutput(); // discard the failed attempt's output
      term.pty = null;
      // Fresh id avoids a "session already exists" collision when the old
      // transcript exists but is corrupt/unresumable.
      term.agentSessionId = await sessionManager.assignAgentSessionId(
        term.sessionId,
      );
      term.hasLaunchedBefore = false;
      term.terminal.write(
        '\r\n\x1b[33m[AgentDock] Could not resume the previous session — '
        'starting a fresh one…\x1b[0m\r\n',
      );
      final session = await sessionManager.getSession(term.sessionId);
      await _launch(term, prompt: session?.input);
      return;
    }

    final output = term.flushOutput();

    // Save the agent session id on EVERY exit so the conversation can
    // always be resumed later. Also save the stripped terminal output so
    // it can be used as context when relaying to another agent.
    await sessionManager.markExited(
      term.sessionId,
      exitCode: code,
      durationMs: durationMs,
      agentSessionId: term.agentSessionId,
      cancelled: term.closing,
      output: output.isNotEmpty ? output : null,
    );

    term.hasLaunchedBefore = true;
    term.pty = null;
    term.exitCode = code;
    if (!term.closing) {
      // Fire a macOS system notification so the user knows the result even
      // when the app is in the background.
      unawaited(
        NotificationService.taskFinished(
          taskName: term.sessionName,
          agentName: term.cli.displayName,
          status: term.effectiveStatus,
        ),
      );
      _exitController.add((sessionId: term.sessionId, exitCode: code));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _memorySyncTimer?.cancel();
    for (final term in _terminals.values) {
      term.closing = true;
      term.closeOutputStream();
      term.pty?.kill();
    }
    _terminals.clear();
    _exitController.close();
    super.dispose();
  }
}
