import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/models/agent_cli.dart';
import 'package:coding_agent_dock/models/autopilot_run_record.dart';
import 'package:coding_agent_dock/services/autopilot_manager.dart';
import 'package:coding_agent_dock/services/settings_service.dart';
import 'package:coding_agent_dock/widgets/autopilot_panel.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  testWidgets('switches to history view and shows saved records', (
    tester,
  ) async {
    await SettingsService.upsertAutopilotRunRecord(
      AutopilotRunRecord(
        id: 'hist-1',
        goal: 'Past autopilot run',
        agentId: 'claude',
        status: 'done',
        startedAt: DateTime(2026, 6, 10, 10, 0),
      ),
    );

    final manager = AutopilotManager(
      createEngine: () => throw UnimplementedError(),
    );
    addTearDown(manager.dispose);

    final agents = <AgentCli>[
      AgentCli(
        id: 'claude',
        displayName: 'Claude Code',
        binaryName: 'claude',
        detected: true,
        lastChecked: DateTime(2026, 6, 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutopilotPanel(manager: manager, agents: agents),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();

    expect(find.text('历史记录'), findsOneWidget);
    expect(find.text('Past autopilot run'), findsOneWidget);
  });

  testWidgets('history restart copies record values into the draft form', (
    tester,
  ) async {
    await SettingsService.upsertAutopilotRunRecord(
      AutopilotRunRecord(
        id: 'hist-2',
        goal: 'Resume this workflow',
        agentId: 'claude',
        status: 'failed',
        startedAt: DateTime(2026, 6, 10, 11, 0),
        workingDirectory: '/tmp/project',
      ),
    );

    final manager = AutopilotManager(
      createEngine: () => throw UnimplementedError(),
    );
    addTearDown(manager.dispose);

    final agents = <AgentCli>[
      AgentCli(
        id: 'claude',
        displayName: 'Claude Code',
        binaryName: 'claude',
        detected: true,
        lastChecked: DateTime(2026, 6, 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutopilotPanel(manager: manager, agents: agents),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新开始'));
    await tester.pumpAndSettle();

    expect(find.text('新增 Autopilot'), findsOneWidget);
    expect(find.text('Resume this workflow'), findsOneWidget);
    expect(find.text('/tmp/project'), findsOneWidget);
  });
}
