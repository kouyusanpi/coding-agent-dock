import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/widgets/broadcast_dialog.dart';

MaterialApp _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows running agent count in title', (tester) async {
    await tester.pumpWidget(
      _wrap(BroadcastDialog(
        runningCount: 3,
        onBroadcast: (_) => 3,
      )),
    );
    await tester.pump();

    expect(find.textContaining('3'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Send button invokes onBroadcast with typed text', (tester) async {
    String? captured;

    await tester.pumpWidget(
      _wrap(BroadcastDialog(
        runningCount: 2,
        onBroadcast: (text) {
          captured = text;
          return 2;
        },
      )),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'summarize your progress');
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured, 'summarize your progress');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Send is skipped when input is empty or whitespace', (tester) async {
    int callCount = 0;

    await tester.pumpWidget(
      _wrap(BroadcastDialog(
        runningCount: 1,
        onBroadcast: (text) {
          callCount++;
          return 1;
        },
      )),
    );
    await tester.pump();

    // tap Send with empty field — should not invoke callback
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(callCount, 0);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog without broadcasting', (tester) async {
    int callCount = 0;

    await tester.pumpWidget(
      _wrap(BroadcastDialog(
        runningCount: 1,
        onBroadcast: (text) {
          callCount++;
          return 1;
        },
      )),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'do not send');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(find.byType(TextField), findsNothing);
  });
}
