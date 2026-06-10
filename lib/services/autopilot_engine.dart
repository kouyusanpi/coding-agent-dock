import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/autopilot_plan.dart';
import '../models/autopilot_run_record.dart';
import '../utils/ansi_utils.dart';
import 'autopilot_llm.dart';

/// Lifecycle states of an autopilot run.
enum AutopilotState {
  idle,
  planning,
  waitingAgent,
  evaluating,
  done,
  failed,
  stopped,
}

/// One timeline entry shown in the autopilot panel.
class AutopilotLogEntry {
  final DateTime time;
  final String message;
  const AutopilotLogEntry(this.time, this.message);
}

/// Autonomous coding loop:
///
///   goal → LLM generates checklist → spawn agent session with first task
///        → wait for the agent to go quiet (or send an IPC stop)
///        → feed output tail to the LLM → LLM updates checklist + decides
///          the next instruction → inject into the agent's stdin → repeat
///        → until finished / max iterations / stopped.
///
/// All session operations are injected as callbacks so the engine is fully
/// unit-testable without PTYs or a real LLM.
class AutopilotEngine extends ChangeNotifier {
  /// Create a session for [agentId] with [input] as the initial prompt.
  /// Returns the new session's DB id, or null on failure.
  final Future<int?> Function({
    required String agentId,
    required String input,
    required String name,
    String? workingDirectory,
  })
  createSession;

  /// Write [text] + Enter into the session's stdin. Returns false when the
  /// session has no live terminal.
  final bool Function(int sessionId, String text) injectInput;

  /// Send raw key bytes (no auto-Enter) into the session's stdin — used to
  /// answer interactive prompts/menus. Returns false when unavailable.
  final bool Function(int sessionId, String rawBytes)? sendKeys;

  /// Read the last [maxLines] lines of the session's terminal buffer
  /// (ANSI already stripped), or null when the session is gone.
  final String? Function(int sessionId, int maxLines) peekOutput;

  /// Subscribe to the session's live output stream, or null when unavailable.
  /// Used purely for quiet detection — payloads are ignored.
  final Stream<String>? Function(int sessionId) subscribeOutput;

  /// Best-effort live status lookup for the session (`created`, `running`,
  /// `completed`, `failed`, ...). Used to avoid false failures while the
  /// terminal is still spinning up.
  final String? Function(int sessionId)? sessionStatus;

  /// Persist a run record for the task-history list.
  final Future<void> Function(AutopilotRunRecord record)? persistRunRecord;

  AutopilotLlm llm;

  AutopilotEngine({
    required this.llm,
    required this.createSession,
    required this.injectInput,
    required this.peekOutput,
    required this.subscribeOutput,
    this.sendKeys,
    this.sessionStatus,
    this.persistRunRecord,
  });

  /// Translate an LLM-named key into the raw bytes to send to the PTY.
  /// Unknown values are sent verbatim (e.g. a single digit/letter).
  @visibleForTesting
  static String mapKeyName(String key) {
    switch (key.trim().toLowerCase()) {
      case 'enter':
      case 'return':
        return '\r';
      case 'space':
        return ' ';
      case 'up':
        return '\x1b[A';
      case 'down':
        return '\x1b[B';
      case 'right':
        return '\x1b[C';
      case 'left':
        return '\x1b[D';
      case 'tab':
        return '\t';
      case 'esc':
      case 'escape':
        return '\x1b';
      case 'backspace':
        return '\x7f';
      case 'ctrl+o':
      case 'ctrl-o':
        return '\x0f';
      case 'ctrl+c':
      case 'ctrl-c':
        return '\x03';
      case 'ctrl+r':
      case 'ctrl-r':
        return '\x12';
      default:
        return key;
    }
  }

  // --- Tunables ---

  /// Seconds of PTY silence after which the agent is considered done with
  /// the current task.
  int quietSeconds = 30;

  /// Hard cap on evaluate→inject cycles, preventing infinite loops.
  int maxIterations = 20;

  /// Lines of terminal output sent to the LLM on each evaluation.
  int outputTailLines = 120;

  /// Max consecutive "agent still working, keep waiting" decisions before the
  /// run is stopped — prevents waiting forever on a stuck agent.
  int maxConsecutiveWaits = 10;

  // --- Run state ---

  AutopilotState _state = AutopilotState.idle;
  String _goal = '';
  List<ChecklistItem> _checklist = [];
  int? _sessionId;
  int _iteration = 0;
  String _runAgentId = '';
  String? _runWorkingDirectory;
  String? _systemPrompt;
  int _consecutiveWaits = 0;
  final List<AutopilotLogEntry> _log = [];
  final List<AutopilotInteraction> _interactions = [];
  int _interactionSeq = 0;
  String? _runRecordId;
  DateTime? _startedAt;
  AutopilotRunRecord? _currentRecord;

  /// Status last written to disk — gates persistence so a run record is only
  /// flushed on meaningful transitions, not on every log line.
  String? _lastPersistedStatus;

  DateTime _lastActivity = DateTime.now();
  Timer? _quietTimer;
  StreamSubscription<String>? _outputSub;
  bool _evaluating = false;

  /// Monotonic stopwatch tracking elapsed time since the last agent output.
  /// Drives the event-driven quiet-detection timer — immune to system-clock
  /// adjustments unlike [DateTime]-based elapsed comparisons.
  final Stopwatch _quietStopwatch = Stopwatch();

  AutopilotState get state => _state;
  String get goal => _goal;
  List<ChecklistItem> get checklist => List.unmodifiable(_checklist);
  int? get sessionId => _sessionId;
  int get iteration => _iteration;
  List<AutopilotLogEntry> get log => List.unmodifiable(_log);

  /// Full request/response transcripts for every LLM call this run, in order.
  List<AutopilotInteraction> get interactions => List.unmodifiable(_interactions);
  AutopilotRunRecord? get currentRecord => _currentRecord;

  /// Agent CLI id of the current/last run (e.g. 'claude').
  String get runAgentId => _runAgentId;

  /// Working directory of the current/last run, or null when not specified.
  String? get runWorkingDirectory => _runWorkingDirectory;

  /// Seconds since the agent last produced output. Drives the quiet-window
  /// countdown in the panel; only meaningful while [state] is waitingAgent.
  int get secondsQuiet => DateTime.now().difference(_lastActivity).inSeconds;
  bool get isRunning =>
      _state == AutopilotState.planning ||
      _state == AutopilotState.waitingAgent ||
      _state == AutopilotState.evaluating;

  void _setState(AutopilotState s) {
    _state = s;
    notifyListeners();
  }

  void _addLog(String message) {
    _log.add(AutopilotLogEntry(DateTime.now(), message));
    if (_log.length > 200) _log.removeAt(0);
    _syncRunRecord();
    notifyListeners();
  }

  /// Record one LLM round-trip (request + raw response) for the panel inspector.
  void _recordInteraction({
    required AutopilotPhase phase,
    required String trigger,
    required LlmTranscript transcript,
    required int durationMs,
    required DateTime startedAt,
    String? summary,
    String? agentOutput,
    String? error,
  }) {
    _interactions.add(AutopilotInteraction(
      index: ++_interactionSeq,
      phase: phase,
      iteration: _iteration,
      trigger: trigger,
      startedAt: startedAt,
      durationMs: durationMs,
      request: transcript.request,
      response: transcript.response,
      summary: summary,
      agentOutput: agentOutput,
      error: error,
    ));
    if (_interactions.length > 100) _interactions.removeAt(0);
    notifyListeners();
  }

  /// Run the planning LLM call and record its interaction. On success returns
  /// the checklist; on failure it logs, transitions to [AutopilotState.failed]
  /// and returns null (the caller must return immediately).
  Future<List<ChecklistItem>?> _generatePlan() async {
    final planStart = DateTime.now();
    try {
      final result = await llm.generatePlan(
        _goal,
        systemPromptExtra: _systemPrompt,
      );
      _recordInteraction(
        phase: AutopilotPhase.plan,
        trigger: '生成计划',
        transcript: result.transcript,
        durationMs: DateTime.now().difference(planStart).inMilliseconds,
        startedAt: planStart,
        summary: '${result.value.length} 步',
      );
      return result.value;
    } catch (e) {
      _recordInteraction(
        phase: AutopilotPhase.plan,
        trigger: '生成计划',
        transcript: e is LlmCallException ? e.transcript : LlmTranscript.empty,
        durationMs: DateTime.now().difference(planStart).inMilliseconds,
        startedAt: planStart,
        error: '$e',
      );
      _addLog('✗ 计划生成失败: $e');
      _finish(AutopilotState.failed);
      return null;
    }
  }

  /// Start a new autopilot run. No-op if one is already in flight.
  Future<void> start({
    required String goal,
    required String agentId,
    String? workingDirectory,
    String? taskName,
    String? systemPrompt,
  }) async {
    if (isRunning) return;
    _goal = goal.trim();
    _checklist = [];
    _iteration = 0;
    _consecutiveWaits = 0;
    _sessionId = null;
    _runAgentId = agentId;
    _runWorkingDirectory = workingDirectory;
    _systemPrompt = systemPrompt?.trim().isEmpty == true
        ? null
        : systemPrompt?.trim();
    _log.clear();
    _interactions.clear();
    _interactionSeq = 0;
    _runRecordId = DateTime.now().microsecondsSinceEpoch.toString();
    _startedAt = DateTime.now();
    _currentRecord = null;
    _lastPersistedStatus = null;

    _setState(AutopilotState.planning);
    _addLog('目标: ${_truncate(_goal, 80)}');
    _addLog('项目目录: ${workingDirectory ?? '（未指定，使用 agent 默认目录）'}');
    _addLog('→ LLM 生成计划中…');
    _syncRunRecord(status: 'planning');

    final planStart = DateTime.now();
    final plan = await _generatePlan();
    if (plan == null) return; // _generatePlan already transitioned to failed
    if (_state != AutopilotState.planning) return; // stopped meanwhile
    final planMs = DateTime.now().difference(planStart).inMilliseconds;

    _checklist = List.of(plan); // defensive copy — engine mutates statuses
    _addLog('← 计划就绪 · ${plan.length} 步 · ${_fmtMs(planMs)}');

    final first = plan.first;
    _checklist[0] = first.copyWith(status: ChecklistStatus.inProgress);
    notifyListeners();

    final runName = taskName?.trim().isNotEmpty == true
        ? taskName!.trim()
        : 'Autopilot: ${_truncate(_goal, 40)}';
    int? id;
    try {
      id = await createSession(
        agentId: agentId,
        input: first.title,
        name: runName,
        workingDirectory: workingDirectory,
      );
    } catch (e) {
      _addLog('✗ 创建 agent 会话失败: $e');
      _finish(AutopilotState.failed);
      return;
    }
    if (_state != AutopilotState.planning) return;
    if (id == null) {
      _addLog('✗ 创建 agent 会话失败（agent 未检测到？）');
      _finish(AutopilotState.failed);
      return;
    }
    _sessionId = id;
    _iteration = 1;
    _addLog('会话 #$id 已启动 ($agentId) · 步骤 1: ${_truncate(first.title, 60)}');
    _syncRunRecord(status: 'running');
    _beginWaiting();
  }

  /// Resume an autopilot loop on an already-reopened [sessionId].
  ///
  /// Unlike [start], this does NOT spawn a new session — the caller has already
  /// reopened the terminal and run the agent's `/resume`, restoring the prior
  /// conversation. The engine regenerates a checklist from [goal], then
  /// immediately evaluates the restored terminal history so the LLM plans the
  /// next step from where the previous run left off (instead of injecting a
  /// fresh first task).
  Future<void> resume({
    required int sessionId,
    required String goal,
    required String agentId,
    String? workingDirectory,
    String? systemPrompt,
  }) async {
    if (isRunning) return;
    _goal = goal.trim();
    _checklist = [];
    _iteration = 0;
    _consecutiveWaits = 0;
    _sessionId = sessionId;
    _runAgentId = agentId;
    _runWorkingDirectory = workingDirectory;
    _systemPrompt = systemPrompt?.trim().isEmpty == true
        ? null
        : systemPrompt?.trim();
    _log.clear();
    _interactions.clear();
    _interactionSeq = 0;
    _runRecordId = DateTime.now().microsecondsSinceEpoch.toString();
    _startedAt = DateTime.now();
    _currentRecord = null;
    _lastPersistedStatus = null;

    _setState(AutopilotState.planning);
    _addLog('恢复任务: ${_truncate(_goal, 80)}');
    _addLog('已附加到会话 #$sessionId（$agentId）');
    _addLog('→ LLM 生成计划中…');
    _syncRunRecord(status: 'planning');

    final plan = await _generatePlan();
    if (plan == null) return;
    if (_state != AutopilotState.planning) return;

    _checklist = List.of(plan);
    _addLog('← 计划就绪 · ${plan.length} 步');
    _iteration = 1;
    _addLog('→ 根据已恢复的历史规划下一步…');
    // Evaluate the restored terminal history straight away — no fresh task is
    // injected; the LLM decides the next step from the existing context.
    unawaited(_evaluate(trigger: '恢复-历史'));
  }

  void _beginWaiting() {
    _setState(AutopilotState.waitingAgent);
    _lastActivity = DateTime.now();
    _quietStopwatch
      ..reset()
      ..start();
    _outputSub?.cancel();
    final stream = _sessionId == null ? null : subscribeOutput(_sessionId!);
    _outputSub = stream?.listen((chunk) {
      if (hasMeaningfulOutput(chunk)) {
        _lastActivity = DateTime.now();
        _quietStopwatch
          ..reset()
          ..start();
        _scheduleQuietCheck();
      }
    });
    _syncRunRecord(status: 'running');
    _scheduleQuietCheck();
  }

  void _scheduleQuietCheck() {
    _quietTimer?.cancel();
    final quietFor = _quietStopwatch.elapsed.inSeconds;
    final remaining = Duration(seconds: quietSeconds) - Duration(seconds: quietFor);
    _quietTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => _evaluate(trigger: 'quiet ${quietSeconds}s'),
    );
  }

  /// Call when the agent posts an IPC `stop` event for [sessionId] —
  /// triggers an immediate evaluation instead of waiting for silence.
  void notifyAgentStopped(int sessionId) {
    if (sessionId != _sessionId) return;
    if (_state != AutopilotState.waitingAgent || _evaluating) return;
    _evaluate(trigger: 'agent stop event');
  }

  Future<void> _evaluate({required String trigger}) async {
    if (_evaluating || _sessionId == null) return;
    _evaluating = true;
    _quietTimer?.cancel();
    _setState(AutopilotState.evaluating);
    _syncRunRecord(status: 'evaluating');

    final liveStatus = sessionStatus?.call(_sessionId!);
    if (liveStatus == 'created') {
      _addLog('… 会话仍在启动，继续等待');
      _evaluating = false;
      _beginWaiting();
      return;
    }
    if (liveStatus == 'failed' || liveStatus == 'cancelled') {
      _addLog('✗ 会话已提前退出 ($liveStatus) — 停止');
      _finish(AutopilotState.failed);
      return;
    }

    final output = peekOutput(_sessionId!, outputTailLines) ?? '';
    final outputLines = output.isEmpty ? 0 : output.split('\n').length;
    if (output.isEmpty) {
      _addLog('⚠ 本轮未读取到终端内容（agent 可能用全屏界面），LLM 将仅凭目标判断');
    } else {
      _addLog('📄 已读取终端历史 $outputLines 行 → 发送给 LLM 规划下一步');
    }
    _addLog('→ LLM 评估中（触发: $trigger）…');

    AutopilotDecision decision;
    final evalStart = DateTime.now();
    try {
      final result = await llm.decideNext(
        goal: _goal,
        checklist: _checklist,
        agentOutput: output,
        iteration: _iteration,
        maxIterations: maxIterations,
        systemPromptExtra: _systemPrompt,
      );
      decision = result.value;
      _recordInteraction(
        phase: AutopilotPhase.evaluate,
        trigger: trigger,
        transcript: result.transcript,
        durationMs: DateTime.now().difference(evalStart).inMilliseconds,
        startedAt: evalStart,
        summary: decision.reason.isNotEmpty ? decision.reason : null,
        agentOutput: output,
      );
    } catch (e) {
      _recordInteraction(
        phase: AutopilotPhase.evaluate,
        trigger: trigger,
        transcript: e is LlmCallException ? e.transcript : LlmTranscript.empty,
        durationMs: DateTime.now().difference(evalStart).inMilliseconds,
        startedAt: evalStart,
        agentOutput: output,
        error: '$e',
      );
      _addLog('✗ LLM 评估失败: $e — 下个静默窗口重试');
      _evaluating = false;
      if (_state == AutopilotState.evaluating) _beginWaiting();
      return;
    }
    final evalMs = DateTime.now().difference(evalStart).inMilliseconds;
    _addLog('← LLM 响应 · ${_fmtMs(evalMs)}');

    if (_state != AutopilotState.evaluating) {
      _evaluating = false;
      return; // stopped during the LLM call
    }

    // Apply checklist updates.
    for (final e in decision.itemUpdates.entries) {
      final idx = _checklist.indexWhere((i) => i.id == e.key);
      if (idx >= 0) {
        _checklist[idx] = _checklist[idx].copyWith(status: e.value);
      }
    }
    if (decision.reason.isNotEmpty) _addLog('💡 ${decision.reason}');

    final allDone = _checklist.every((i) => i.status == ChecklistStatus.done);

    if (decision.finished || allDone) {
      _addLog(allDone ? '✓ 全部步骤完成' : '✓ Autopilot 结束');
      _finish(AutopilotState.done);
      return;
    }

    // Agent still working — don't interrupt; keep waiting (bounded).
    if (decision.wait) {
      _consecutiveWaits++;
      if (_consecutiveWaits >= maxConsecutiveWaits) {
        _addLog('✗ agent 连续 $maxConsecutiveWaits 次仍无明确进展 — 停止');
        _finish(AutopilotState.failed);
        return;
      }
      _addLog(
        '⏳ agent 仍在工作，继续等待 '
        '[$_consecutiveWaits/$maxConsecutiveWaits]',
      );
      _evaluating = false;
      _beginWaiting();
      return;
    }
    _consecutiveWaits = 0;

    if (_iteration >= maxIterations) {
      _addLog('✗ 达到最大迭代次数 ($maxIterations) — 停止');
      _finish(AutopilotState.failed);
      return;
    }

    // Interactive prompt/menu — answer with a single keystroke (no auto-Enter).
    final keyName = decision.keys?.trim();
    if (keyName != null && keyName.isNotEmpty) {
      final send = sendKeys;
      final sent = send != null && send(_sessionId!, mapKeyName(keyName));
      if (!sent) {
        final liveStatus = sessionStatus?.call(_sessionId!);
        if (liveStatus == 'created') {
          _addLog('… 会话尚未就绪，本轮继续等待');
          _evaluating = false;
          _beginWaiting();
          return;
        }
        _addLog('✗ 无法发送按键（会话已关闭）— 停止');
        _finish(AutopilotState.failed);
        return;
      }
      _iteration++;
      _addLog('⌨ 发送按键回应交互提示: $keyName');
      _evaluating = false;
      _beginWaiting();
      return;
    }

    final next = decision.nextInput?.trim();
    if (next == null || next.isEmpty) {
      _addLog('✗ LLM 未给出下一步指令 — 停止');
      _finish(AutopilotState.failed);
      return;
    }

    // Mark the first pending item as in-progress (best-effort bookkeeping).
    final pendingIdx = _checklist.indexWhere(
      (i) => i.status == ChecklistStatus.pending,
    );
    if (pendingIdx >= 0 &&
        !_checklist.any((i) => i.status == ChecklistStatus.inProgress)) {
      _checklist[pendingIdx] = _checklist[pendingIdx].copyWith(
        status: ChecklistStatus.inProgress,
      );
    }

    final sent = injectInput(_sessionId!, next);
    if (!sent) {
      final liveStatus = sessionStatus?.call(_sessionId!);
      if (liveStatus == 'created') {
        _addLog('… 会话尚未就绪，本轮继续等待');
        _evaluating = false;
        _beginWaiting();
        return;
      }
      _addLog('✗ 会话终端已关闭${liveStatus != null ? ' ($liveStatus)' : ''} — 停止');
      _finish(AutopilotState.failed);
      return;
    }
    _iteration++;
    _addLog('⌨ 注入步骤 $_iteration: ${_truncate(next, 80)}');
    _evaluating = false;
    _syncRunRecord(status: 'running');
    _beginWaiting();
  }

  /// Stop the run (user action). Safe to call in any state.
  void stop() {
    if (!isRunning) return;
    _teardown();
    _addLog('⏹ 用户手动停止');
    _setState(AutopilotState.stopped);
    _syncRunRecord(status: 'stopped', finished: true);
  }

  void _finish(AutopilotState end) {
    _teardown();
    _setState(end);
    _syncRunRecord(
      status: switch (end) {
        AutopilotState.done => 'done',
        AutopilotState.failed => 'failed',
        AutopilotState.stopped => 'stopped',
        _ => 'running',
      },
      finished:
          end == AutopilotState.done ||
          end == AutopilotState.failed ||
          end == AutopilotState.stopped,
    );
  }

  void _teardown() {
    _quietTimer?.cancel();
    _quietTimer = null;
    _outputSub?.cancel();
    _outputSub = null;
    _quietStopwatch
      ..stop()
      ..reset();
    _evaluating = false;
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  static String _fmtMs(int ms) =>
      ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s';

  @visibleForTesting
  static bool hasMeaningfulOutput(String chunk) {
    final visible = AnsiUtils.stripAnsi(
      chunk,
    ).replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]'), '');
    return visible.trim().isNotEmpty;
  }

  void _syncRunRecord({String? status, bool finished = false}) {
    final runId = _runRecordId;
    final startedAt = _startedAt;
    if (runId == null || startedAt == null) return;
    final doneSteps = _checklist
        .where((i) => i.status == ChecklistStatus.done)
        .length;
    final detail = _log.isEmpty ? null : _log.last.message;
    final record =
        (_currentRecord ??
                AutopilotRunRecord(
                  id: runId,
                  goal: _goal,
                  agentId: _runAgentId,
                  workingDirectory: _runWorkingDirectory,
                  startedAt: startedAt,
                  status: status ?? _recordStatusForState(_state),
                ))
            .copyWith(
              goal: _goal,
              agentId: _runAgentId,
              workingDirectory: _runWorkingDirectory,
              sessionId: _sessionId,
              status: status ?? _recordStatusForState(_state),
              endedAt: finished ? DateTime.now() : null,
              iteration: _iteration,
              totalSteps: _checklist.length,
              doneSteps: doneSteps,
              detail: detail,
            );
    _currentRecord = record;
    final persist = persistRunRecord;
    if (persist == null) return;
    // Persist to disk only on meaningful transitions (status change or run end),
    // not on every log line — the live in-memory record drives the UI, and
    // flushing the whole history JSON on each append is needlessly expensive.
    final newStatus = record.status;
    if (finished || newStatus != _lastPersistedStatus) {
      _lastPersistedStatus = newStatus;
      unawaited(persist(record));
    }
  }

  static String _recordStatusForState(AutopilotState state) => switch (state) {
    AutopilotState.planning => 'planning',
    AutopilotState.waitingAgent => 'running',
    AutopilotState.evaluating => 'evaluating',
    AutopilotState.done => 'done',
    AutopilotState.failed => 'failed',
    AutopilotState.stopped => 'stopped',
    AutopilotState.idle => 'idle',
  };
}