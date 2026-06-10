import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/models/agent_cli.dart';
import 'package:claude_code_cli_flutter/services/settings_service.dart';
import 'package:claude_code_cli_flutter/widgets/app_sidebar.dart';

AgentCli _agent(String id, String name) => AgentCli(
      id: id,
      displayName: name,
      binaryName: id,
      detected: true,
      lastChecked: DateTime(2026),
    );

Widget _app({
  required List<AgentCli> agents,
  ValueChanged<AgentCli>? onHideAgent,
  int hiddenAgentCount = 0,
  VoidCallback? onShowHiddenAgents,
}) =>
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 256,
          height: 600,
          child: AppSidebar(
            agents: agents,
            selectedAgentIds: const {},
            onToggleAgent: (_) {},
            onRescan: () {},
            onHideAgent: onHideAgent,
            hiddenAgentCount: hiddenAgentCount,
            onShowHiddenAgents: onShowHiddenAgents,
            taskPanel: const SizedBox.expand(key: Key('task_panel')),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  testWidgets('right-click on a built-in agent shows Hide and hides it',
      (tester) async {
    AgentCli? hidden;
    await tester.pumpWidget(_app(
      agents: [_agent('claude', 'Claude Code')],
      onHideAgent: (a) => hidden = a,
    ));
    await tester.pumpAndSettle();

    // Secondary-tap the agent row to open the context menu.
    await tester.tap(find.text('Claude Code'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Hide from list'), findsOneWidget);
    await tester.tap(find.text('Hide from list'));
    await tester.pumpAndSettle();

    expect(hidden, isNotNull);
    expect(hidden!.id, 'claude');
  });

  testWidgets('hidden footer shows count and restores on tap', (tester) async {
    var restored = false;
    await tester.pumpWidget(_app(
      agents: [_agent('claude', 'Claude Code')],
      hiddenAgentCount: 3,
      onShowHiddenAgents: () => restored = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 hidden'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(restored, isTrue);
  });

  testWidgets('no hidden footer when count is zero', (tester) async {
    await tester.pumpWidget(_app(
      agents: [_agent('claude', 'Claude Code')],
      hiddenAgentCount: 0,
      onShowHiddenAgents: () {},
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('hidden'), findsNothing);
  });
}
