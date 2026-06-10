import 'dart:convert';

/// Status of a single checklist item in an autopilot plan.
enum ChecklistStatus { pending, inProgress, done, failed }

ChecklistStatus checklistStatusFrom(String? raw) => switch (raw) {
      'in_progress' || 'inProgress' => ChecklistStatus.inProgress,
      'done' || 'completed' => ChecklistStatus.done,
      'failed' => ChecklistStatus.failed,
      _ => ChecklistStatus.pending,
    };

String checklistStatusLabel(ChecklistStatus s) => switch (s) {
      ChecklistStatus.pending => 'pending',
      ChecklistStatus.inProgress => 'in_progress',
      ChecklistStatus.done => 'done',
      ChecklistStatus.failed => 'failed',
    };

/// One step in the autopilot-generated plan.
class ChecklistItem {
  final String id;
  final String title;
  final ChecklistStatus status;

  const ChecklistItem({
    required this.id,
    required this.title,
    this.status = ChecklistStatus.pending,
  });

  ChecklistItem copyWith({String? title, ChecklistStatus? status}) =>
      ChecklistItem(
        id: id,
        title: title ?? this.title,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': checklistStatusLabel(status),
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        status: checklistStatusFrom(json['status'] as String?),
      );
}

/// Which LLM call an interaction represents.
enum AutopilotPhase { plan, evaluate }

/// A single LLM round-trip captured in full for the panel's expandable
/// "LLM 调用" inspector — request prompt sent, raw response received, timing,
/// and a short human summary. Lets the user see exactly what was asked and
/// what came back for every planning/evaluation step.
class AutopilotInteraction {
  /// 1-based sequence number within the run.
  final int index;
  final AutopilotPhase phase;

  /// Loop iteration this call belongs to (0 for the initial plan).
  final int iteration;

  /// What triggered this call (e.g. '生成计划', 'quiet 30s', 'agent stop event').
  final String trigger;
  final DateTime startedAt;
  final int durationMs;

  /// Full prompt text sent to the model (system + user message).
  final String request;

  /// Raw response content returned by the model.
  final String response;

  /// Short one-line summary (plan: step count; evaluate: decision reason).
  final String? summary;

  /// The cleaned terminal snapshot fed to the LLM (evaluate calls only) — the
  /// agent history the LLM actually read to plan the next step.
  final String? agentOutput;

  /// Non-null when the call failed (network error or unparseable response).
  final String? error;

  const AutopilotInteraction({
    required this.index,
    required this.phase,
    required this.iteration,
    required this.trigger,
    required this.startedAt,
    required this.durationMs,
    required this.request,
    required this.response,
    this.summary,
    this.agentOutput,
    this.error,
  });

  bool get ok => error == null;
}

/// The LLM's decision after evaluating agent output for one iteration.
class AutopilotDecision {
  /// Map of checklist item id → new status, as judged from the agent output.
  final Map<String, ChecklistStatus> itemUpdates;

  /// The next instruction to inject into the coding agent's stdin.
  /// Null/empty when [finished] or [wait] is true.
  final String? nextInput;

  /// A single keystroke to send raw (no auto-Enter) when the agent is waiting
  /// at an interactive prompt/menu — e.g. 'enter', 'space', 'up', 'down', 'y',
  /// 'n', a digit, 'ctrl+o'. Takes priority over [nextInput] when set.
  final String? keys;

  /// True when the agent is still actively working and should NOT be
  /// interrupted — the engine keeps waiting instead of injecting.
  final bool wait;

  /// True when the LLM judges the whole goal complete (or unrecoverable).
  final bool finished;

  /// Free-text reasoning — shown in the autopilot panel timeline.
  final String reason;

  const AutopilotDecision({
    this.itemUpdates = const {},
    this.nextInput,
    this.keys,
    this.wait = false,
    this.finished = false,
    this.reason = '',
  });

  factory AutopilotDecision.fromJson(Map<String, dynamic> json) {
    final updatesRaw = json['itemUpdates'];
    final updates = <String, ChecklistStatus>{};
    if (updatesRaw is Map) {
      for (final e in updatesRaw.entries) {
        updates[e.key.toString()] =
            checklistStatusFrom(e.value?.toString());
      }
    }
    return AutopilotDecision(
      itemUpdates: updates,
      nextInput: json['nextInput'] as String?,
      keys: json['keys'] as String?,
      wait: json['wait'] == true,
      finished: json['finished'] == true,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// Extracts the first JSON object or array from [text].
///
/// LLMs often wrap JSON in markdown fences or prose; this finds the outermost
/// balanced `{...}` or `[...]` block and parses it. Returns null when nothing
/// parseable is found.
dynamic extractJson(String text) {
  // Fast path: the whole string is valid JSON.
  try {
    return jsonDecode(text.trim());
  } catch (_) {}

  // Strip markdown fences if present.
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fenced != null) {
    try {
      return jsonDecode(fenced.group(1)!.trim());
    } catch (_) {}
  }

  // Scan for the first balanced JSON object/array.
  for (final open in ['{', '[']) {
    final close = open == '{' ? '}' : ']';
    final start = text.indexOf(open);
    if (start < 0) continue;
    var depth = 0;
    var inString = false;
    var escape = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == r'\') {
        escape = true;
        continue;
      }
      if (c == '"') inString = !inString;
      if (inString) continue;
      if (c == open) depth++;
      if (c == close) {
        depth--;
        if (depth == 0) {
          try {
            return jsonDecode(text.substring(start, i + 1));
          } catch (_) {
            break;
          }
        }
      }
    }
  }
  return null;
}
