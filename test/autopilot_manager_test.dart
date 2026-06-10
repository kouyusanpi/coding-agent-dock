import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/models/autopilot_plan.dart';
import 'package:coding_agent_dock/services/autopilot_engine.dart';
import 'package:coding_agent_dock/services/autopilot_llm.dart';
import 'package:coding_agent_dock/services/autopilot_manager.dart';
import 'package:coding_agent_dock/services/settings_service.dart';

class _FakeLlm implements AutopilotLlm {
  final List<ChecklistItem> plan;
  final List<AutopilotDecision> decisions;
  int _decisionIndex = 0;

  _FakeLlm({required this.plan, required this.decisions});

  @override
  Future<LlmResult<List<ChecklistItem>>> generatePlan(
    String goal, {
    String? systemPromptExtra,
  }) async => LlmResult(value: plan, transcript: LlmTranscript.empty);

  @override
  Future<LlmResult<AutopilotDecision>> decideNext({
    required String goal,
    required List<ChecklistItem> checklist,
    required String agentOutput,
    required int iteration,
    required int maxIterations,
    String? systemPromptExtra,
  }) async {
    final idx = _decisionIndex.clamp(0, decisions.length - 1);
    _decisionIndex++;
    return LlmResult(value: decisions[idx], transcript: LlmTranscript.empty);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  test('supports multiple running autopilots at the same time', () async {
    var nextSessionId = 100;
    AutopilotEngine buildEngine() {
      final output = StreamController<String>.broadcast();
      addTearDown(output.close);
      return AutopilotEngine(
        llm: _FakeLlm(
          plan: const [ChecklistItem(id: '1', title: 'Implement')],
          decisions: const [
            AutopilotDecision(nextInput: 'continue', reason: 'keep going'),
          ],
        ),
        createSession:
            ({
              required agentId,
              required input,
              required name,
              workingDirectory,
            }) async => nextSessionId++,
        injectInput: (sessionId, text) => true,
        peekOutput: (sessionId, maxLines) => 'working',
        subscribeOutput: (sessionId) => output.stream,
        sessionStatus: (sessionId) => 'running',
        persistRunRecord: SettingsService.upsertAutopilotRunRecord,
      )..quietSeconds = 600;
    }

    final manager = AutopilotManager(createEngine: buildEngine);
    addTearDown(manager.dispose);

    await manager.startRun(goal: 'Goal A', agentId: 'claude');
    await manager.startRun(goal: 'Goal B', agentId: 'codex');

    expect(manager.runningEngines, hasLength(2));
    expect(manager.runningRecords.map((r) => r.goal).toSet(), {
      'Goal A',
      'Goal B',
    });
  });

  test('finished runs move into history records', () async {
    final output = StreamController<String>.broadcast();
    addTearDown(output.close);

    final manager = AutopilotManager(
      createEngine: () =>
          AutopilotEngine(
              llm: _FakeLlm(
                plan: const [ChecklistItem(id: '1', title: 'Implement')],
                decisions: const [
                  AutopilotDecision(
                    itemUpdates: {'1': ChecklistStatus.done},
                    finished: true,
                    reason: 'done',
                  ),
                ],
              ),
              createSession:
                  ({
                    required agentId,
                    required input,
                    required name,
                    workingDirectory,
                  }) async => 101,
              injectInput: (sessionId, text) => true,
              peekOutput: (sessionId, maxLines) => 'done',
              subscribeOutput: (sessionId) => output.stream,
              sessionStatus: (sessionId) => 'running',
              persistRunRecord: SettingsService.upsertAutopilotRunRecord,
            )
            ..quietSeconds = 0,
    );
    addTearDown(manager.dispose);

    await manager.startRun(goal: 'Ship it', agentId: 'claude');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(manager.runningRecords, isEmpty);
    expect(manager.historyRecords.map((r) => r.goal), contains('Ship it'));
  });
}
