import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

import '../models/autopilot_plan.dart';

/// Connection settings for the autopilot's planning/evaluation LLM.
///
/// Any OpenAI-compatible endpoint works: OpenAI, DeepSeek, Qwen (DashScope),
/// Kimi (Moonshot), Ollama (`http://localhost:11434/v1`), etc.
class AutopilotLlmConfig {
  final String baseUrl;
  final String apiKey;
  final String model;

  const AutopilotLlmConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  bool get isValid => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;
}

/// Raw request + response text for one LLM round-trip. Surfaced verbatim in the
/// panel's expandable inspector so the user can see exactly what was sent and
/// received.
class LlmTranscript {
  final String request;
  final String response;
  const LlmTranscript({required this.request, required this.response});

  static const empty = LlmTranscript(request: '', response: '');
}

/// Parsed value of an LLM call bundled with its raw [transcript].
class LlmResult<T> {
  final T value;
  final LlmTranscript transcript;
  const LlmResult({required this.value, required this.transcript});
}

/// Thrown when an LLM call fails — network error or an unparseable response.
/// Carries the [transcript] so the panel can still show what was sent and the
/// (possibly malformed) response received.
class LlmCallException implements Exception {
  final String message;
  final LlmTranscript transcript;
  const LlmCallException(this.message, this.transcript);

  @override
  String toString() => message;
}

/// Abstract LLM brain for the autopilot — mockable in tests.
abstract class AutopilotLlm {
  /// Generate an ordered checklist plan for [goal].
  ///
  /// [systemPromptExtra] (the per-task prompt) is appended to the base
  /// [planPrompt] when non-empty.
  Future<LlmResult<List<ChecklistItem>>> generatePlan(
    String goal, {
    String? systemPromptExtra,
  });

  /// Evaluate the agent's latest output and decide the next step.
  Future<LlmResult<AutopilotDecision>> decideNext({
    required String goal,
    required List<ChecklistItem> checklist,
    required String agentOutput,
    required int iteration,
    required int maxIterations,
    String? systemPromptExtra,
  });
}

/// Langchain-backed implementation talking to any OpenAI-compatible API.
class OpenAiCompatLlm implements AutopilotLlm {
  final ChatOpenAI _chat;

  /// User-owned planning system prompt. Defaults to [defaultPlanPrompt].
  final String planPrompt;

  /// User-owned evaluation/decision system prompt. Defaults to
  /// [defaultDecidePrompt].
  final String decidePrompt;

  OpenAiCompatLlm(
    AutopilotLlmConfig config, {
    String? planPrompt,
    String? decidePrompt,
  })  : planPrompt = (planPrompt == null || planPrompt.trim().isEmpty)
            ? defaultPlanPrompt
            : planPrompt,
        decidePrompt = (decidePrompt == null || decidePrompt.trim().isEmpty)
            ? defaultDecidePrompt
            : decidePrompt,
        _chat = ChatOpenAI(
          apiKey: config.apiKey,
          baseUrl: config.baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
          defaultOptions: ChatOpenAIOptions(
            model: config.model,
            temperature: 0.2,
          ),
        );

  /// Default planning prompt — the working seed users can edit. Defines the
  /// JSON-array output contract the engine parses; editing away the contract
  /// will break parsing (the panel offers a "恢复默认" to restore this).
  static const defaultPlanPrompt = '''
You are the planning brain of an autonomous coding orchestrator. The user
gives you a software engineering goal. Break it into a short, ordered
checklist of concrete coding tasks that a coding agent CLI (like Claude Code)
can execute one at a time.

Rules:
- 3 to 8 items. Each item must be a self-contained instruction.
- Order matters: earlier items unblock later ones.
- Include a final verification step (run tests / build).
- Write each "title" in the SAME LANGUAGE as the user's goal
  (Chinese goal → Chinese titles; English goal → English titles).
- The JSON structure itself (keys) must stay in English.
- Respond with ONLY a JSON array, no prose:
  [{"id": "1", "title": "..."}, {"id": "2", "title": "..."}]''';

  /// Default evaluation/decision prompt — the working seed users can edit.
  /// Defines the JSON-object output contract the engine parses.
  static const defaultDecidePrompt = '''
You are the supervising brain of an autonomous coding loop. A coding agent CLI
is working on a goal; you receive its RECENT TERMINAL OUTPUT, the goal, and the
current checklist. Your job is to read the output and decide the next move.

Respond with ONLY a JSON object, no prose:
{
  "itemUpdates": {"<itemId>": "done" | "in_progress" | "failed"},
  "nextInput": "<the next instruction to type into the agent, or null>",
  "keys": "<a single keystroke to answer an interactive prompt, or null>",
  "wait": true | false,
  "finished": true | false,
  "reason": "<one sentence that REFERENCES concrete details from the output>"
}

CRITICAL — ground every decision in the actual terminal output:
- Base itemUpdates, nextInput and reason STRICTLY on what the output shows. Your
  "reason" MUST mention a concrete detail the agent actually produced (a file it
  edited, an error it hit, a result it printed). Never answer generically.
- If the output shows the agent is STILL actively working (mid-edit, a command
  running, streaming progress, a spinner), set "wait": true, "nextInput": null.
  Do NOT interrupt a working agent.
- Do NOT repeat an instruction the output shows you already gave. If your last
  instruction did not take effect, diagnose why from the output instead of
  resending it.
- Avoid vague commands like a bare "continue". Tell the agent SPECIFICALLY what
  to do next, derived from what it just produced.

Interactive prompts / menus / selections:
- If the output shows the agent WAITING on an interactive prompt — a menu, a
  selection list, a yes/no confirmation, a "press X to …" hint, a permission
  request — answer it with the "keys" field instead of "nextInput".
- "keys" is ONE keystroke from: "enter", "space", "up", "down", "left",
  "right", "tab", "esc", "backspace", "ctrl+o", "ctrl+c", a single digit, or a
  single letter (e.g. "y", "n"). Use it to confirm/navigate/select.
  Examples: a "Press Enter to continue" → "keys":"enter"; a "[y/N]" prompt →
  "keys":"y"; a numbered menu where you pick option 2 → "keys":"2"; an
  arrow-key list → "keys":"down" then a later "keys":"enter".
- Use "nextInput" (a typed line + Enter) for giving the agent a new task; use
  "keys" (a single raw keypress) for answering its UI. Set only one of them.

Other rules:
- Mark an item "done" ONLY if the output explicitly shows it was completed.
- If the agent hit an error, set nextInput to a concrete fix grounded in the
  error text.
- Set finished=true when ALL items are done, or the loop is unrecoverable.
- nextInput must be plain text the agent executes — no markdown, ONE step.
- If the terminal output is empty or unreadable, set "wait": true (give the
  agent more time) rather than guessing.
- Write "nextInput" and "reason" in the SAME LANGUAGE as the goal. JSON keys and
  status values ("done"/"in_progress"/"failed") stay in English.''';

  /// Render a chat request as readable text for the transcript inspector.
  static String _formatRequest(String system, String user) =>
      '【System】\n$system\n\n【User】\n$user';

  /// Append [extra] (global + per-task system prompt) to [base] when present.
  static String _withExtra(String base, String? extra) {
    final e = extra?.trim() ?? '';
    return e.isEmpty ? base : '$base\n\n--- 附加要求 ---\n$e';
  }

  @override
  Future<LlmResult<List<ChecklistItem>>> generatePlan(
    String goal, {
    String? systemPromptExtra,
  }) async {
    final systemMsg = _withExtra(planPrompt, systemPromptExtra);
    final userMsg = 'Goal: $goal';
    final request = _formatRequest(systemMsg, userMsg);

    String content;
    try {
      final result = await _chat.invoke(
        PromptValue.chat([
          ChatMessage.system(systemMsg),
          ChatMessage.humanText(userMsg),
        ]),
      );
      content = result.output.content;
    } catch (e) {
      throw LlmCallException(
        '请求大模型失败: $e',
        LlmTranscript(request: request, response: ''),
      );
    }

    final transcript = LlmTranscript(request: request, response: content);
    final parsed = extractJson(content);
    if (parsed is! List) {
      throw LlmCallException('计划响应不是 JSON 数组', transcript);
    }
    final items = parsed
        .whereType<Map<String, dynamic>>()
        .map(ChecklistItem.fromJson)
        .where((i) => i.title.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      throw LlmCallException('返回的计划为空', transcript);
    }
    return LlmResult(value: items, transcript: transcript);
  }

  @override
  Future<LlmResult<AutopilotDecision>> decideNext({
    required String goal,
    required List<ChecklistItem> checklist,
    required String agentOutput,
    required int iteration,
    required int maxIterations,
    String? systemPromptExtra,
  }) async {
    final systemMsg = _withExtra(decidePrompt, systemPromptExtra);
    final checklistJson = checklist.map((i) => i.toJson()).toList().toString();
    final userMsg =
        '''
Goal: $goal
Iteration: $iteration / $maxIterations
Checklist: $checklistJson

--- Recent agent terminal output (tail) ---
$agentOutput
--- end output ---''';
    final request = _formatRequest(systemMsg, userMsg);

    String content;
    try {
      final result = await _chat.invoke(
        PromptValue.chat([
          ChatMessage.system(systemMsg),
          ChatMessage.humanText(userMsg),
        ]),
      );
      content = result.output.content;
    } catch (e) {
      throw LlmCallException(
        '请求大模型失败: $e',
        LlmTranscript(request: request, response: ''),
      );
    }

    final transcript = LlmTranscript(request: request, response: content);
    final parsed = extractJson(content);
    if (parsed is! Map<String, dynamic>) {
      throw LlmCallException('决策响应不是 JSON 对象', transcript);
    }
    return LlmResult(
      value: AutopilotDecision.fromJson(parsed),
      transcript: transcript,
    );
  }
}
