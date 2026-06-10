import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:claude_code_cli_flutter/widgets/skill_manager_dialog.dart';

Widget _host(String workingDir) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  SkillManagerDialog.show(context, workingDirectory: workingDir),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

/// Open the dialog and let its async skill-load settle. We pump fixed
/// durations rather than [WidgetTester.pumpAndSettle] because the loading
/// state shows a CircularProgressIndicator, which animates forever and would
/// make pumpAndSettle time out.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump(); // build dialog
  await tester.pump(const Duration(milliseconds: 300)); // listAll resolves
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('agentdock_skill_ui');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets('New Skill form validates an empty name', (tester) async {
    await tester.pumpWidget(_host(tmp.path));
    await _open(tester);

    await tester.tap(find.text('New Skill'));
    await tester.pump();

    // The edit form scrolls; bring the Create button into view before tapping.
    await tester.ensureVisible(find.text('Create'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Name is required.'), findsOneWidget);
  });

  testWidgets('creates a project skill and writes SKILL.md', (tester) async {
    await tester.pumpWidget(_host(tmp.path));
    await _open(tester);

    await tester.tap(find.text('New Skill'));
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Code Review'), 'My Skill');
    await tester.enterText(
        find.widgetWithText(TextField, 'What it does and when it triggers…'),
        'Does a thing.');
    await tester.pump();

    // Choose project scope so it writes into the temp dir.
    await tester.ensureVisible(find.text('This project'));
    await tester.pump();
    await tester.tap(find.text('This project'));
    await tester.pump();

    await tester.ensureVisible(find.text('Create'));
    await tester.pump();

    // Create does real disk I/O, which only runs on the real event loop —
    // drive it via runAsync and poll for the file rather than a fixed delay
    // (a fixed delay flakes under parallel-test load).
    final file = File(
        p.join(tmp.path, '.claude', 'skills', 'my-skill', 'SKILL.md'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Create'));
      for (var i = 0; i < 100 && !file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('name: My Skill'));
    expect(content, contains('description: Does a thing.'));
  });
}
