import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/database/database.dart';
import 'package:coding_agent_dock/l10n/app_localizations.dart';
import 'package:coding_agent_dock/models/agent_cli.dart';
import 'package:coding_agent_dock/services/session_manager.dart';
import 'package:coding_agent_dock/services/terminal_sessions_controller.dart';
import 'package:coding_agent_dock/widgets/task_panel.dart';

TaskSession _session(int id, String name, {String? workingDirectory}) =>
    TaskSession(
      id: id,
      name: name,
      agentCliId: 'claude',
      status: 'created',
      createdAt: DateTime(2026, 1, id),
      updatedAt: DateTime(2026),
      workingDirectory: workingDirectory,
    );

AgentCli _agent(String id, String displayName) => AgentCli(
      id: id,
      displayName: displayName,
      binaryName: id,
      lastChecked: DateTime(2026),
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

  Widget app({
    required List<TaskSession> sessions,
    bool groupByDir = false,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TaskPanel(
          sessionsStream: Stream.value(sessions).asBroadcastStream(),
          terminals: terminals,
          searchQuery: '',
          agents: [_agent('claude', 'Claude Code')],
          selectedAgentIds: const {},
          onToggleAgent: (_) {},
          onClearAgents: () {},
          agentNameOf: (id) => id,
          onOpen: (_) {},
          onDelete: (_) {},
          onRename: (s, n) {},
          onDispatchTo: (s, c) {},
          onDispatchToAll: (_) {},
          onClone: (_) {},
          onUpdateNotes: (id, notes) async {},
          onUpdateColorLabel: (id, label) async {},
          onNewTask: () {},
          pinnedIds: const {},
          onTogglePin: (_) {},
        ),
      ),
    );
  }

  group('group-by-directory toggle', () {
    final sessions = [
      _session(1, 'Task Alpha', workingDirectory: '/home/user/projectA'),
      _session(2, 'Task Beta', workingDirectory: '/home/user/projectB'),
      _session(3, 'Task Gamma', workingDirectory: '/home/user/projectA'),
      _session(4, 'Task Delta'),
    ];

    testWidgets('group button is visible in task panel header',
        (tester) async {
      await tester.pumpWidget(app(sessions: sessions));
      await tester.pump();
      // The group-by-dir button shows a folder icon.
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('sessions all visible before grouping is toggled',
        (tester) async {
      await tester.pumpWidget(app(sessions: sessions));
      await tester.pump();
      expect(find.text('Task Alpha'), findsOneWidget);
      expect(find.text('Task Beta'), findsOneWidget);
      expect(find.text('Task Gamma'), findsOneWidget);
      expect(find.text('Task Delta'), findsOneWidget);
    });

    testWidgets('toggling group button shows group headers', (tester) async {
      await tester.pumpWidget(app(sessions: sessions));
      await tester.pump();

      // Tap the folder button to enable grouping.
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();

      // Group headers for both project dirs should appear.
      expect(find.text('projectA'), findsOneWidget);
      expect(find.text('projectB'), findsOneWidget);
      // "Other" group for sessions with no working directory.
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('sessions remain visible after grouping is enabled',
        (tester) async {
      await tester.pumpWidget(app(sessions: sessions));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();

      expect(find.text('Task Alpha'), findsOneWidget);
      expect(find.text('Task Beta'), findsOneWidget);
      expect(find.text('Task Gamma'), findsOneWidget);
      expect(find.text('Task Delta'), findsOneWidget);
    });

    testWidgets('toggling again restores flat list and hides group headers',
        (tester) async {
      await tester.pumpWidget(app(sessions: sessions));
      await tester.pump();

      // Enable grouping.
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();
      expect(find.text('projectA'), findsOneWidget);

      // Disable grouping — group headers should disappear.
      await tester.tap(find.byIcon(Icons.folder_copy_rounded));
      await tester.pump();
      expect(find.text('projectA'), findsNothing);
    });

    testWidgets('sessions with no working dir appear in Other group',
        (tester) async {
      final withoutDir = [
        _session(1, 'No Dir Task'),
      ];
      await tester.pumpWidget(app(sessions: withoutDir));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump();

      expect(find.text('Other'), findsOneWidget);
      expect(find.text('No Dir Task'), findsOneWidget);
    });
  });
}
