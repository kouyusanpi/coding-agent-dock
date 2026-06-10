import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/models/autopilot_run_record.dart';
import 'package:coding_agent_dock/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  test('upsertAutopilotRunRecord stores and replaces records by id', () async {
    final startedAt = DateTime(2026, 6, 10, 10, 0);
    await SettingsService.upsertAutopilotRunRecord(
      AutopilotRunRecord(
        id: 'run-1',
        goal: 'First run',
        agentId: 'claude',
        status: 'running',
        startedAt: startedAt,
      ),
    );
    await SettingsService.upsertAutopilotRunRecord(
      AutopilotRunRecord(
        id: 'run-1',
        goal: 'First run',
        agentId: 'claude',
        status: 'done',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 5)),
        doneSteps: 3,
        totalSteps: 3,
      ),
    );

    final items = SettingsService.autopilotRunHistory;
    expect(items, hasLength(1));
    expect(items.single.status, 'done');
    expect(items.single.doneSteps, 3);
  });

  test('autopilotRunHistory returns newest records first', () async {
    await SettingsService.upsertAutopilotRunRecord(
      AutopilotRunRecord(
        id: 'older',
        goal: 'Older run',
        agentId: 'claude',
        status: 'failed',
        startedAt: DateTime(2026, 6, 10, 9, 0),
      ),
    );
    await SettingsService.upsertAutopilotRunRecord(
      AutopilotRunRecord(
        id: 'newer',
        goal: 'Newer run',
        agentId: 'codex',
        status: 'done',
        startedAt: DateTime(2026, 6, 10, 11, 0),
      ),
    );

    final items = SettingsService.autopilotRunHistory;
    expect(items.map((e) => e.id).toList(), ['newer', 'older']);
  });
}
