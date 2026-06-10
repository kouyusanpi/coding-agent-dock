import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:claude_code_cli_flutter/database/database.dart';
import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/widgets/cluster_comparison_dialog.dart';

TaskSession _makeSession({
  required int id,
  required String agentCliId,
  required String status,
  String? batchId,
  String? input,
  int? durationMs,
}) =>
    TaskSession(
      id: id,
      name: 'Task $id',
      agentCliId: agentCliId,
      status: status,
      workingDirectory: null,
      description: null,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      completedAt: null,
      exitCode: null,
      durationMs: durationMs,
      input: input,
      agentSessionId: null,
      output: null,
      notes: null,
      colorLabel: null,
      batchId: batchId,
    );

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Provider<AppDatabase>(
        create: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
        dispose: (_, db) => db.close(),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('ClusterComparisonDialog', () {
    final sessions = [
      _makeSession(
          id: 1,
          agentCliId: 'claude',
          status: 'completed',
          batchId: 'batch-1',
          durationMs: 5000,
          input: 'Fix the auth bug'),
      _makeSession(
          id: 2,
          agentCliId: 'codex',
          status: 'running',
          batchId: 'batch-1',
          input: 'Fix the auth bug'),
      _makeSession(
          id: 3,
          agentCliId: 'gemini',
          status: 'failed',
          batchId: 'batch-1',
          durationMs: 2000,
          input: 'Fix the auth bug'),
    ];

    testWidgets('shows correct agent count in title', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return TextButton(
          onPressed: () => ClusterComparisonDialog.show(
            ctx,
            sessions: sessions,
            agentNameOf: (id) => id.toUpperCase(),
            onOpen: (_) {},
          ),
          child: const Text('Open'),
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('shows one row per session', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return TextButton(
          onPressed: () => ClusterComparisonDialog.show(
            ctx,
            sessions: sessions,
            agentNameOf: (id) => id.toUpperCase(),
            onOpen: (_) {},
          ),
          child: const Text('Open'),
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('CLAUDE'), findsOneWidget);
      expect(find.text('CODEX'), findsOneWidget);
      expect(find.text('GEMINI'), findsOneWidget);
    });

    testWidgets('tapping a row calls onOpen and closes dialog', (tester) async {
      TaskSession? opened;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return TextButton(
          onPressed: () => ClusterComparisonDialog.show(
            ctx,
            sessions: sessions,
            agentNameOf: (id) => id,
            onOpen: (s) => opened = s,
          ),
          child: const Text('Open'),
        );
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Hover over the first row to reveal "Open" button
      final row = find.ancestor(
          of: find.text('claude'), matching: find.byType(MouseRegion)).first;
      final gesture = await tester.createGesture();
      await gesture.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();

      // Tap the row
      await tester.tap(find.text('claude'));
      await tester.pumpAndSettle();

      expect(opened, isNotNull);
      expect(opened!.agentCliId, 'claude');
      // Dialog should be dismissed
      expect(find.byType(ClusterComparisonDialog), findsNothing);
    });
  });
}
