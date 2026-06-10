import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/l10n/app_localizations.dart';
import 'package:coding_agent_dock/widgets/shared_memory_dialog.dart';

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
  testWidgets('shows pre-existing shared memory in the editor', (tester) async {
    // withContent bypasses async _load() — dart:io events don't fire inside
    // testWidgets/fakeAsync without runAsync, so content is injected directly.
    await tester.pumpWidget(
      _wrap(SharedMemoryDialog.withContent(
        projectPath: '/tmp/test-project',
        content: 'existing notes',
      )),
    );
    await tester.pump();

    expect(find.text('existing notes'), findsOneWidget);
  });

  testWidgets('Save invokes the save handler and closes the dialog', (tester) async {
    String? capturedContent;

    // onSave replaces the dart:io writeShared call — avoids async IO in fakeAsync.
    // The lambda completes as a microtask, so Navigator.pop() fires on the next pump.
    await tester.pumpWidget(
      _wrap(SharedMemoryDialog.withContent(
        projectPath: '/tmp/test-project',
        content: '',
        onSave: (content) async => capturedContent = content,
      )),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'brand new memory');
    await tester.tap(find.text('Save'));
    await tester.pump(); // _save(): setState(_saving=true) + onSave() starts
    await tester.pump(); // onSave Future resolves, Navigator.pop() fires
    await tester.pumpAndSettle(); // settle dialog-close animation

    expect(find.byType(TextField), findsNothing);
    expect(capturedContent, 'brand new memory');
  });
}
