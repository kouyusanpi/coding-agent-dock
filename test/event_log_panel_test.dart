import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/services/event_log_service.dart';
import 'package:claude_code_cli_flutter/widgets/event_log_panel.dart';

/// Returns true if any RichText in the tree contains [substring] in its plain text.
Finder richTextContaining(String substring) => find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText().contains(substring),
    );

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('EventLogPanel', () {
    late EventLogService log;

    setUp(() => log = EventLogService());
    tearDown(() => log.dispose());

    testWidgets('shows empty state when no events', (tester) async {
      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Event Log'), findsOneWidget);
      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('renders events when populated', (tester) async {
      log.log(ClusterEventKind.sessionStarted, sessionName: 'test-session');
      log.log(ClusterEventKind.sessionCompleted, sessionName: 'done-session');

      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(richTextContaining('test-session'), findsOneWidget);
      expect(richTextContaining('done-session'), findsOneWidget);
      expect(richTextContaining('started'), findsWidgets);
      expect(richTextContaining('completed'), findsWidgets);
    });

    testWidgets('shows count in footer', (tester) async {
      log.log(ClusterEventKind.sessionStarted, sessionName: 'a');
      log.log(ClusterEventKind.sessionFailed, sessionName: 'b');

      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 total'), findsOneWidget);
    });

    testWidgets('Clear button removes all events', (tester) async {
      log.log(ClusterEventKind.sessionStarted, sessionName: 'a');

      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('No events yet'), findsOneWidget);
      expect(log.count, 0);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Event Log'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Event Log'), findsNothing);
    });

    testWidgets('shows detail text when event has detail', (tester) async {
      log.log(
        ClusterEventKind.ipcNotify,
        sessionName: 'agent-1',
        detail: 'hello from agent',
      );

      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('hello from agent'), findsOneWidget);
    });

    testWidgets('reacts to new events added after open', (tester) async {
      await tester.pumpWidget(
        _wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => EventLogPanel.show(ctx, logService: log),
            child: const Text('open'),
          ),
        )),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('No events yet'), findsOneWidget);

      log.log(ClusterEventKind.sessionStarted, sessionName: 'live-session');
      await tester.pumpAndSettle();

      expect(richTextContaining('live-session'), findsOneWidget);
      expect(find.text('No events yet'), findsNothing);
    });
  });
}
