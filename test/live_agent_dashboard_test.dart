import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/database/database.dart';
import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/services/session_manager.dart';
import 'package:claude_code_cli_flutter/services/terminal_sessions_controller.dart';
import 'package:claude_code_cli_flutter/widgets/live_agent_dashboard.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  late AppDatabase db;
  late TerminalSessionsController terminals;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    terminals = TerminalSessionsController(SessionManager(db));
  });

  tearDown(() async {
    terminals.dispose();
    await db.close();
  });

  group('LiveAgentDashboard', () {
    testWidgets('shows title', (tester) async {
      await tester.pumpWidget(_wrap(LiveAgentDashboard(
        terminals: terminals,
        onJumpTo: (_) {},
        onInject: (_, _) {},
      )));
      expect(find.text('Live Agent Dashboard'), findsOneWidget);
    });

    testWidgets('shows empty state when no sessions open', (tester) async {
      await tester.pumpWidget(_wrap(LiveAgentDashboard(
        terminals: terminals,
        onJumpTo: (_) {},
        onInject: (_, _) {},
      )));
      expect(find.text('No open sessions'), findsOneWidget);
    });

    testWidgets('shows footer hint text', (tester) async {
      await tester.pumpWidget(_wrap(LiveAgentDashboard(
        terminals: terminals,
        onJumpTo: (_) {},
        onInject: (_, _) {},
      )));
      expect(find.textContaining('⇧⌘D to toggle'), findsOneWidget);
    });
  });
}
