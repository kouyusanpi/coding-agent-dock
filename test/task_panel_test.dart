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

/// Create a minimal TaskSession for testing.
TaskSession _session(int id, String name, String agentCliId, {
  String status = 'created',
  String? notes,
  int? durationMs,
  DateTime? createdAt,
}) =>
    TaskSession(
      id: id,
      name: name,
      agentCliId: agentCliId,
      status: status,
      notes: notes,
      durationMs: durationMs,
      createdAt: createdAt ?? DateTime(2026, 1, id),
      updatedAt: DateTime(2026),
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
    required List<AgentCli> agents,
    Set<String> selectedAgentIds = const {},
    Set<int> pinnedIds = const {},
    String searchQuery = '',
    ValueChanged<String>? onToggleAgent,
    VoidCallback? onClearAgents,
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
          searchQuery: searchQuery,
          agents: agents,
          selectedAgentIds: selectedAgentIds,
          onToggleAgent: onToggleAgent ?? (_) {},
          onClearAgents: onClearAgents ?? () {},
          agentNameOf: (id) => id,
          onOpen: (_) {},
          onDelete: (_) {},
          onRename: (session, name) {},
          onDispatchTo: (session, cli) {},
          onDispatchToAll: (_) {},
          onClone: (_) {},
          onUpdateNotes: (id, notes) async {},
          onUpdateColorLabel: (id, label) async {},
          onNewTask: () {},
          pinnedIds: pinnedIds,
          onTogglePin: (_) {},
        ),
      ),
    );
  }

  final sessions = [
    _session(1, 'Alpha refactor', 'claude'),
    _session(2, 'Beta migration', 'codex'),
  ];
  final agents = [_agent('claude', 'Claude Code'), _agent('codex', 'Codex')];

  // ─────────────────────────────────────────────────────────────────────
  // Inline task search
  // ─────────────────────────────────────────────────────────────────────
  group('inline task search', () {
    testWidgets('filters the list as the user types', (tester) async {
      await tester.pumpWidget(app(sessions: sessions, agents: agents));
      await tester.pump();
      expect(find.text('Alpha refactor'), findsOneWidget);
      expect(find.text('Beta migration'), findsOneWidget);

      await tester.enterText(
          find.byKey(TaskPanel.searchFieldKey), 'alpha');
      await tester.pump();
      expect(find.text('Alpha refactor'), findsOneWidget);
      expect(find.text('Beta migration'), findsNothing);
    });

    testWidgets('combines with the global search query', (tester) async {
      await tester.pumpWidget(
          app(sessions: sessions, agents: agents, searchQuery: 'beta'));
      await tester.pump();
      expect(find.text('Beta migration'), findsOneWidget);
      expect(find.text('Alpha refactor'), findsNothing);
    });

    testWidgets('matches sessions by note content', (tester) async {
      final withNotes = [
        _session(1, 'Task A', 'claude', notes: 'fixed the auth bug'),
        _session(2, 'Task B', 'claude', notes: 'optimized queries'),
      ];
      await tester.pumpWidget(app(sessions: withNotes, agents: agents));
      await tester.pump();

      await tester.enterText(
          find.byKey(TaskPanel.searchFieldKey), 'auth');
      await tester.pump();
      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Agent-type filter
  // ─────────────────────────────────────────────────────────────────────
  group('agent-type filter', () {
    testWidgets('selected agents filter the task list', (tester) async {
      await tester.pumpWidget(app(
        sessions: sessions,
        agents: agents,
        selectedAgentIds: {'claude'},
      ));
      await tester.pump();
      expect(find.text('Alpha refactor'), findsOneWidget);
      expect(find.text('Beta migration'), findsNothing);
    });

    testWidgets('renders the filter dropdown button with filter icon',
        (tester) async {
      await tester.pumpWidget(app(sessions: sessions, agents: agents));
      await tester.pump();
      // Dropdown button is present with a filter icon.
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      // "All" label appears in the agent filter dropdown button (and in the
      // status filter row) — confirm at least one is present.
      expect(find.textContaining('All'), findsWidgets);
    });

    testWidgets('opening the dropdown shows each agent as a checkbox row',
        (tester) async {
      await tester.pumpWidget(app(sessions: sessions, agents: agents));
      await tester.pump();

      // Tap the dropdown button to open the popup menu.
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Agent names appear inside the popup.
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
    });

    testWidgets('tapping an agent row in the dropdown toggles it',
        (tester) async {
      String? toggled;
      await tester.pumpWidget(app(
        sessions: sessions,
        agents: agents,
        onToggleAgent: (id) => toggled = id,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Codex'));
      expect(toggled, 'codex');
    });

    testWidgets('tapping All agents row in the dropdown clears the selection',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(app(
        sessions: sessions,
        agents: agents,
        selectedAgentIds: {'claude'},
        onClearAgents: () => cleared = true,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // The first row in the popup is "All agents" — tap it.
      // Use .last because the status-filter chip also contains "All" text
      // and the popup overlay is rendered after the base widget tree.
      await tester.tap(find.textContaining('All').last);
      expect(cleared, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Session pinning
  // ─────────────────────────────────────────────────────────────────────
  group('session pinning', () {
    testWidgets('pinned session appears above unpinned ones', (tester) async {
      final ordered = [
        _session(1, 'Apple task', 'claude'),
        _session(2, 'Zebra task', 'claude'), // will be pinned
        _session(3, 'Mango task', 'claude'),
      ];
      await tester.pumpWidget(app(
        sessions: ordered,
        agents: agents,
        pinnedIds: {2}, // pin Zebra
      ));
      await tester.pump();

      // All three visible
      expect(find.text('Apple task'), findsOneWidget);
      expect(find.text('Zebra task'), findsOneWidget);

      // Pinned session (Zebra, id=2) must render above Apple (id=1)
      final zebraY = tester.getTopLeft(find.text('Zebra task')).dy;
      final appleY = tester.getTopLeft(find.text('Apple task')).dy;
      expect(zebraY, lessThan(appleY),
          reason: 'pinned Zebra should appear above unpinned Apple');
    });

    testWidgets('unpinned sessions retain original order below pinned ones',
        (tester) async {
      final ordered = [
        _session(1, 'First', 'claude',
            createdAt: DateTime(2026, 1, 3)), // newest
        _session(2, 'Pinned', 'claude',
            createdAt: DateTime(2026, 1, 2)),
        _session(3, 'Third', 'claude',
            createdAt: DateTime(2026, 1, 1)), // oldest
      ];
      await tester.pumpWidget(app(
        sessions: ordered,
        agents: agents,
        pinnedIds: {2},
      ));
      await tester.pump();

      // Pinned (id=2) must be above both unpinned ones
      final pinnedY = tester.getTopLeft(find.text('Pinned')).dy;
      final firstY = tester.getTopLeft(find.text('First')).dy;
      final thirdY = tester.getTopLeft(find.text('Third')).dy;
      expect(pinnedY, lessThan(firstY));
      expect(pinnedY, lessThan(thirdY));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Status filter chips
  // ─────────────────────────────────────────────────────────────────────
  group('status filter', () {
    final mixed = [
      _session(1, 'Running task', 'claude', status: 'running'),
      _session(2, 'Done task', 'claude', status: 'completed'),
      _session(3, 'Failed task', 'claude', status: 'failed'),
    ];

    testWidgets('shows all sessions when no status filter is active',
        (tester) async {
      await tester.pumpWidget(app(sessions: mixed, agents: agents));
      await tester.pump();
      expect(find.text('Running task'), findsOneWidget);
      expect(find.text('Done task'), findsOneWidget);
      expect(find.text('Failed task'), findsOneWidget);
    });

    testWidgets('Running chip hides completed and failed sessions',
        (tester) async {
      await tester.pumpWidget(app(sessions: mixed, agents: agents));
      await tester.pump();

      // Tap the "Running" status chip
      await tester.tap(find.text('Running'));
      await tester.pump();

      expect(find.text('Running task'), findsOneWidget);
      expect(find.text('Done task'), findsNothing);
      expect(find.text('Failed task'), findsNothing);
    });

    testWidgets('Completed chip hides running and failed sessions',
        (tester) async {
      await tester.pumpWidget(app(sessions: mixed, agents: agents));
      await tester.pump();

      await tester.tap(find.text('Completed'));
      await tester.pump();

      expect(find.text('Done task'), findsOneWidget);
      expect(find.text('Running task'), findsNothing);
      expect(find.text('Failed task'), findsNothing);
    });

    testWidgets('tapping active chip again clears the filter', (tester) async {
      await tester.pumpWidget(app(sessions: mixed, agents: agents));
      await tester.pump();

      // Activate filter
      await tester.tap(find.text('Running'));
      await tester.pump();
      expect(find.text('Done task'), findsNothing);

      // Tap again to deactivate
      await tester.tap(find.text('Running'));
      await tester.pump();
      expect(find.text('Done task'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Sort control
  // ─────────────────────────────────────────────────────────────────────
  group('sort control', () {
    final unsorted = [
      _session(1, 'Zebra project', 'claude'),
      _session(2, 'Apple project', 'claude'),
      _session(3, 'Mango project', 'claude'),
    ];

    testWidgets('sort button is present', (tester) async {
      await tester.pumpWidget(app(sessions: unsorted, agents: agents));
      await tester.pump();
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('A → Z sort orders sessions alphabetically', (tester) async {
      await tester.pumpWidget(app(sessions: unsorted, agents: agents));
      await tester.pump();

      // Open sort popup
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // Select A → Z
      await tester.tap(find.text('A → Z'));
      await tester.pump();

      // Verify vertical order: Apple < Mango < Zebra
      final appleY = tester.getTopLeft(find.text('Apple project')).dy;
      final mangoY = tester.getTopLeft(find.text('Mango project')).dy;
      final zebraY = tester.getTopLeft(find.text('Zebra project')).dy;
      expect(appleY, lessThan(mangoY),
          reason: 'Apple should appear before Mango in A→Z order');
      expect(mangoY, lessThan(zebraY),
          reason: 'Mango should appear before Zebra in A→Z order');
    });

    testWidgets('sort icon changes color when non-default sort is active',
        (tester) async {
      await tester.pumpWidget(app(sessions: unsorted, agents: agents));
      await tester.pump();

      // Default sort icon is text500 (gray)
      final defaultIcon = tester.widget<Icon>(find.byIcon(Icons.sort));
      expect(defaultIcon.color, isNot(equals(const Color(0xFF6B80FF))));

      // Activate A → Z sort
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A → Z'));
      await tester.pump();

      // After sort change: icon should be sort_rounded (non-default)
      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
    });
  });
}
