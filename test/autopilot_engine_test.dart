import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/models/autopilot_plan.dart';
import 'package:coding_agent_dock/services/autopilot_engine.dart';
import 'package:coding_agent_dock/services/autopilot_llm.dart';

/// Scriptable fake LLM: returns a fixed plan and a queue of decisions.
class FakeLlm implements AutopilotLlm {
  List<ChecklistItem> plan;
  final List<AutopilotDecision> decisions;
  int decideCalls = 0;
  bool throwOnPlan = false;
  bool throwOnDecide = false;
  String? lastSystemPromptExtra;

  FakeLlm({required this.plan, this.decisions = const []});

  @override
  Future<LlmResult<List<ChecklistItem>>> generatePlan(
    String goal, {
    String? systemPromptExtra,
  }) async {
    lastSystemPromptExtra = systemPromptExtra;
    if (throwOnPlan) {
      throw const LlmCallException(
        'LLM unreachable',
        LlmTranscript(request: 'plan-request', response: ''),
      );
    }
    return LlmResult(
      value: plan,
      transcript: const LlmTranscript(
        request: 'plan-request',
        response: 'plan-response',
      ),
    );
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
    lastSystemPromptExtra = systemPromptExtra;
    if (throwOnDecide) {
      throw const LlmCallException(
        'decide failed',
        LlmTranscript(request: 'decide-request', response: 'bad json'),
      );
    }
    final d = decisions[decideCalls.clamp(0, decisions.length - 1)];
    decideCalls++;
    return LlmResult(
      value: d,
      transcript: const LlmTranscript(
        request: 'decide-request',
        response: 'decide-response',
      ),
    );
  }
}

/// Test harness around the engine with in-memory session plumbing.
class Harness {
  final FakeLlm llm;
  late final AutopilotEngine engine;
  final injected = <String>[];
  final sentKeys = <String>[];
  final outputController = StreamController<String>.broadcast();
  String terminalOutput = 'agent output';
  bool failCreate = false;
  bool failInject = false;
  String? sessionStatus = 'running';

  Harness(this.llm) {
    engine = AutopilotEngine(
      llm: llm,
      createSession:
          ({
            required agentId,
            required input,
            required name,
            workingDirectory,
          }) async => failCreate ? null : 101,
      injectInput: (sessionId, text) {
        if (failInject) return false;
        injected.add(text);
        return true;
      },
      sendKeys: (sessionId, raw) {
        sentKeys.add(raw);
        return true;
      },
      peekOutput: (sessionId, maxLines) => terminalOutput,
      subscribeOutput: (sessionId) => outputController.stream,
      sessionStatus: (sessionId) => sessionStatus,
    );
    engine.quietSeconds = 0; // quiet immediately in tests
  }

  Future<void> pump([int ms = 60]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  void dispose() {
    engine.dispose();
    outputController.close();
  }
}

const _planTwo = [
  ChecklistItem(id: '1', title: 'Write the feature'),
  ChecklistItem(id: '2', title: 'Run the tests'),
];

void main() {
  group('extractJson', () {
    test('parses bare JSON object', () {
      expect(extractJson('{"a": 1}'), {'a': 1});
    });

    test('parses JSON inside markdown fences', () {
      final r = extractJson('Here:\n```json\n{"finished": true}\n```done');
      expect(r, {'finished': true});
    });

    test('parses JSON embedded in prose', () {
      final r = extractJson('Sure! {"nextInput": "run tests"} hope it helps');
      expect(r, {'nextInput': 'run tests'});
    });

    test('parses array with nested braces in strings', () {
      final r = extractJson('[{"title": "use {x} syntax"}]');
      expect((r as List).first['title'], 'use {x} syntax');
    });

    test('returns null for garbage', () {
      expect(extractJson('no json here'), isNull);
    });
  });

  group('AutopilotDecision', () {
    test('fromJson parses item updates and next input', () {
      final d = AutopilotDecision.fromJson({
        'itemUpdates': {'1': 'done', '2': 'in_progress'},
        'nextInput': 'run flutter test',
        'finished': false,
        'reason': 'step 1 complete',
      });
      expect(d.itemUpdates['1'], ChecklistStatus.done);
      expect(d.itemUpdates['2'], ChecklistStatus.inProgress);
      expect(d.nextInput, 'run flutter test');
      expect(d.finished, isFalse);
      expect(d.reason, 'step 1 complete');
    });

    test('fromJson tolerates missing fields', () {
      final d = AutopilotDecision.fromJson({});
      expect(d.itemUpdates, isEmpty);
      expect(d.nextInput, isNull);
      expect(d.finished, isFalse);
    });
  });

  group('AutopilotEngine', () {
    test('ansi-only control output does not count as agent activity', () {
      expect(
        AutopilotEngine.hasMeaningfulOutput('\x1b[?25l\x1b[2K\r'),
        isFalse,
      );
      expect(AutopilotEngine.hasMeaningfulOutput('real output line'), isTrue);
    });

    test(
      'start generates plan and creates a session with first task',
      () async {
        final h = Harness(
          FakeLlm(
            plan: _planTwo,
            decisions: const [
              AutopilotDecision(finished: true, reason: 'all good'),
            ],
          ),
        );
        await h.engine.start(goal: 'Build it', agentId: 'claude');
        expect(h.engine.sessionId, 101);
        expect(h.engine.checklist.first.status, ChecklistStatus.inProgress);
        expect(h.engine.iteration, 1);
        h.dispose();
      },
    );

    test('quiet detection triggers evaluation and finishes', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(
              itemUpdates: {
                '1': ChecklistStatus.done,
                '2': ChecklistStatus.done,
              },
              finished: true,
              reason: 'everything done',
            ),
          ],
        ),
      );
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump();
      expect(h.engine.state, AutopilotState.done);
      expect(
        h.engine.checklist.every((i) => i.status == ChecklistStatus.done),
        isTrue,
      );
      h.dispose();
    });

    test('decision with nextInput injects and continues the loop', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(
              itemUpdates: {'1': ChecklistStatus.done},
              nextInput: 'now run the tests',
              reason: 'feature written',
            ),
            AutopilotDecision(
              itemUpdates: {'2': ChecklistStatus.done},
              finished: true,
              reason: 'tests pass',
            ),
          ],
        ),
      );
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump(150);
      expect(h.injected, contains('now run the tests'));
      expect(h.engine.state, AutopilotState.done);
      expect(h.engine.iteration, 2);
      h.dispose();
    });

    test('mapKeyName translates named keys to control bytes', () {
      expect(AutopilotEngine.mapKeyName('enter'), '\r');
      expect(AutopilotEngine.mapKeyName('space'), ' ');
      expect(AutopilotEngine.mapKeyName('up'), '\x1b[A');
      expect(AutopilotEngine.mapKeyName('down'), '\x1b[B');
      expect(AutopilotEngine.mapKeyName('ctrl+o'), '\x0f');
      expect(AutopilotEngine.mapKeyName('esc'), '\x1b');
      // Unknown / single char sent verbatim.
      expect(AutopilotEngine.mapKeyName('y'), 'y');
      expect(AutopilotEngine.mapKeyName('2'), '2');
    });

    test('keys decision sends a raw keystroke without injecting text', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(keys: 'enter', reason: '回应"按回车继续"提示'),
            AutopilotDecision(finished: true, reason: 'done'),
          ],
        ),
      );
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump(150);
      expect(h.sentKeys, contains('\r'));
      expect(h.injected, isEmpty);
      h.dispose();
    });

    test('wait decision keeps waiting without injecting', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(wait: true, reason: 'agent 仍在编辑文件'),
          ],
        ),
      );
      // Quiet detection off; trigger a single evaluation deterministically.
      h.engine.quietSeconds = 600;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      h.engine.notifyAgentStopped(101);
      await h.pump();
      // Stays waiting, never injected an instruction.
      expect(h.injected, isEmpty);
      expect(h.engine.state, AutopilotState.waitingAgent);
      h.engine.stop();
      h.dispose();
    });

    test('too many consecutive waits stops the run', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(wait: true, reason: 'still working'),
          ],
        ),
      );
      h.engine.maxConsecutiveWaits = 3;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump(400);
      expect(h.engine.state, AutopilotState.failed);
      expect(h.injected, isEmpty);
      h.dispose();
    });

    test('max iterations stops the loop as failed', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            // Never finishes, always asks for another step.
            AutopilotDecision(nextInput: 'keep going', reason: 'more work'),
          ],
        ),
      );
      h.engine.maxIterations = 3;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump(400);
      expect(h.engine.state, AutopilotState.failed);
      expect(h.engine.iteration, 3);
      h.dispose();
    });

    test('plan failure sets failed state', () async {
      final llm = FakeLlm(plan: _planTwo)..throwOnPlan = true;
      final h = Harness(llm);
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      expect(h.engine.state, AutopilotState.failed);
      h.dispose();
    });

    test('session creation failure sets failed state', () async {
      final h = Harness(FakeLlm(plan: _planTwo));
      h.failCreate = true;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      expect(h.engine.state, AutopilotState.failed);
      h.dispose();
    });

    test('empty nextInput without finished stops as failed', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(reason: 'stuck, no idea')],
        ),
      );
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump();
      expect(h.engine.state, AutopilotState.failed);
      h.dispose();
    });

    test('stop() cancels a waiting run', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(nextInput: 'next', reason: 'r')],
        ),
      );
      h.engine.quietSeconds = 600; // never quiet on its own
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      expect(h.engine.isRunning, isTrue);
      h.engine.stop();
      expect(h.engine.state, AutopilotState.stopped);
      expect(h.engine.isRunning, isFalse);
      h.dispose();
    });

    test('notifyAgentStopped triggers immediate evaluation', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(finished: true, reason: 'done via stop hook'),
          ],
        ),
      );
      h.engine.quietSeconds = 600; // quiet detection effectively off
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      h.engine.notifyAgentStopped(101);
      await h.pump();
      expect(h.engine.state, AutopilotState.done);
      h.dispose();
    });

    test('notifyAgentStopped ignores other session ids', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(finished: true, reason: 'x')],
        ),
      );
      h.engine.quietSeconds = 600;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      h.engine.notifyAgentStopped(999);
      await h.pump();
      expect(h.engine.state, AutopilotState.waitingAgent);
      h.engine.stop();
      h.dispose();
    });

    test('output activity defers quiet detection', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(finished: true, reason: 'done')],
        ),
      );
      h.engine.quietSeconds = 1;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      // Keep the terminal noisy for ~300ms — engine must stay waiting.
      for (var i = 0; i < 6; i++) {
        h.outputController.add('chunk');
        await h.pump(50);
      }
      expect(h.engine.state, AutopilotState.waitingAgent);
      h.engine.stop();
      h.dispose();
    });

    test('ansi-only idle repaint does not defer quiet detection', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(finished: true, reason: 'done')],
        ),
      );
      h.engine.quietSeconds = 1;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      for (var i = 0; i < 6; i++) {
        h.outputController.add('\x1b[?25l\x1b[2K\r');
        await h.pump(50);
      }
      await h.pump(900);
      expect(h.engine.state, AutopilotState.done);
      h.dispose();
    });

    test('start is a no-op while already running', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(nextInput: 'go', reason: 'r')],
        ),
      );
      h.engine.quietSeconds = 600;
      await h.engine.start(goal: 'First goal', agentId: 'claude');
      await h.engine.start(goal: 'Second goal', agentId: 'codex');
      expect(h.engine.goal, 'First goal');
      h.engine.stop();
      h.dispose();
    });

    test('all-done checklist finishes even without finished flag', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(
              itemUpdates: {
                '1': ChecklistStatus.done,
                '2': ChecklistStatus.done,
              },
              nextInput: 'irrelevant',
              reason: 'both done',
            ),
          ],
        ),
      );
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump();
      expect(h.engine.state, AutopilotState.done);
      h.dispose();
    });

    test('records an interaction transcript for the plan call', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(finished: true, reason: 'done'),
          ],
        ),
      );
      h.engine.quietSeconds = 600;
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      final plan = h.engine.interactions.firstWhere(
        (i) => i.phase == AutopilotPhase.plan,
      );
      expect(plan.request, 'plan-request');
      expect(plan.response, 'plan-response');
      expect(plan.ok, isTrue);
      expect(plan.summary, contains('步'));
      h.engine.stop();
      h.dispose();
    });

    test('records request and response for each evaluation', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(finished: true, reason: 'all done'),
          ],
        ),
      );
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump();
      final eval = h.engine.interactions.firstWhere(
        (i) => i.phase == AutopilotPhase.evaluate,
      );
      expect(eval.request, 'decide-request');
      expect(eval.response, 'decide-response');
      expect(eval.summary, 'all done');
      h.dispose();
    });

    test('evaluate interaction records the terminal snapshot fed to LLM',
        () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(finished: true, reason: 'done'),
          ],
        ),
      );
      h.terminalOutput = 'Step 1 complete\nAll tests green';
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      await h.pump();
      final eval = h.engine.interactions.firstWhere(
        (i) => i.phase == AutopilotPhase.evaluate,
      );
      expect(eval.agentOutput, 'Step 1 complete\nAll tests green');
      h.dispose();
    });

    test('failed plan call still records its transcript', () async {
      final llm = FakeLlm(plan: _planTwo)..throwOnPlan = true;
      final h = Harness(llm);
      await h.engine.start(goal: 'Build it', agentId: 'claude');
      expect(h.engine.state, AutopilotState.failed);
      final plan = h.engine.interactions.single;
      expect(plan.ok, isFalse);
      expect(plan.error, contains('LLM unreachable'));
      expect(plan.request, 'plan-request');
      h.dispose();
    });

    test(
      'resume attaches to an existing session and evaluates history',
      () async {
        final h = Harness(
          FakeLlm(
            plan: _planTwo,
            decisions: const [
              AutopilotDecision(
                itemUpdates: {'1': ChecklistStatus.done},
                nextInput: '继续实现第二步',
                reason: '历史显示第一步已完成',
              ),
              AutopilotDecision(
                itemUpdates: {'2': ChecklistStatus.done},
                finished: true,
                reason: '全部完成',
              ),
            ],
          ),
        );
        await h.engine.resume(
          sessionId: 555,
          goal: 'Build it',
          agentId: 'claude',
        );
        await h.pump(200);
        // Attached to the existing session, not a freshly created one.
        expect(h.engine.sessionId, 555);
        // Planned the next step from history and injected it (no fresh task).
        expect(h.injected, contains('继续实现第二步'));
        h.dispose();
      },
    );

    test('resume is a no-op while already running', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [AutopilotDecision(nextInput: 'go', reason: 'r')],
        ),
      );
      h.engine.quietSeconds = 600;
      await h.engine.start(goal: 'First', agentId: 'claude');
      await h.engine.resume(sessionId: 999, goal: 'Second', agentId: 'codex');
      expect(h.engine.goal, 'First');
      expect(h.engine.sessionId, 101);
      h.engine.stop();
      h.dispose();
    });

    test('threads the system prompt into LLM calls', () async {
      final llm = FakeLlm(
        plan: _planTwo,
        decisions: const [AutopilotDecision(finished: true, reason: 'done')],
      );
      final h = Harness(llm);
      await h.engine.start(
        goal: 'Build it',
        agentId: 'claude',
        systemPrompt: '始终用中文回复',
      );
      await h.pump();
      expect(llm.lastSystemPromptExtra, '始终用中文回复');
      h.dispose();
    });

    test('blank system prompt is normalized to null', () async {
      final llm = FakeLlm(
        plan: _planTwo,
        decisions: const [AutopilotDecision(finished: true, reason: 'done')],
      );
      final h = Harness(llm);
      await h.engine.start(
        goal: 'Build it',
        agentId: 'claude',
        systemPrompt: '   ',
      );
      await h.pump();
      expect(llm.lastSystemPromptExtra, isNull);
      h.dispose();
    });

    test('interactions are cleared when a new run starts', () async {
      final h = Harness(
        FakeLlm(
          plan: _planTwo,
          decisions: const [
            AutopilotDecision(finished: true, reason: 'done'),
          ],
        ),
      );
      await h.engine.start(goal: 'First', agentId: 'claude');
      await h.pump();
      expect(h.engine.interactions, isNotEmpty);
      await h.engine.start(goal: 'Second', agentId: 'claude');
      // First interaction of the new run is the fresh plan call (index 1).
      expect(h.engine.interactions.first.index, 1);
      h.dispose();
    });

    test(
      'created session status waits instead of failing on inject race',
      () async {
        final h = Harness(
          FakeLlm(
            plan: _planTwo,
            decisions: const [
              AutopilotDecision(
                nextInput: 'continue',
                reason: 'waiting for terminal',
              ),
            ],
          ),
        );
        h.failInject = true;
        h.sessionStatus = 'created';
        await h.engine.start(goal: 'Build it', agentId: 'claude');
        await h.pump();
        expect(h.engine.state, AutopilotState.waitingAgent);
        h.dispose();
      },
    );
  });
}
