import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/services/settings_service.dart';
import 'package:claude_code_cli_flutter/widgets/app_sidebar.dart';

Widget _app() => MaterialApp(
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
          child: AppSidebar(
            agents: const [],
            selectedAgentIds: const {},
            onToggleAgent: (_) {},
            onRescan: () {},
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

  testWidgets('dragging the splitter grows the agent section and persists',
      (tester) async {
    await tester.pumpWidget(_app());
    final before = tester.getSize(find.byKey(const Key('task_panel')));

    // touchSlopY: 0 — deliver the exact offset to the drag recognizer.
    // +40 stays inside the elastic bounds of the default 600px-tall test
    // viewport (larger drags get clamped to keep the task section >= 160).
    await tester.drag(
        find.byKey(AppSidebar.splitterKey), const Offset(0, 40),
        touchSlopY: 0);
    await tester.pumpAndSettle();

    final after = tester.getSize(find.byKey(const Key('task_panel')));
    expect(after.height, before.height - 40);
    expect(SettingsService.agentSectionHeight,
        AppSidebar.defaultAgentSectionHeight + 40);
  });

  testWidgets('agent section height is clamped to its minimum',
      (tester) async {
    await tester.pumpWidget(_app());

    await tester.drag(
        find.byKey(AppSidebar.splitterKey), const Offset(0, -500),
        touchSlopY: 0);
    await tester.pumpAndSettle();

    expect(SettingsService.agentSectionHeight,
        AppSidebar.minAgentSectionHeight);
  });
}
