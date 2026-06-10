import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/services/settings_service.dart';
import 'package:coding_agent_dock/widgets/prompt_templates_dialog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  group('SettingsService.promptTemplates', () {
    test('returns 5 built-in defaults when no data saved', () {
      final templates = SettingsService.promptTemplates;
      expect(templates.length, 5);
      expect(templates.first.name, isNotEmpty);
      expect(templates.first.text, isNotEmpty);
    });

    test('round-trips saved templates', () async {
      final saved = [
        (name: 'Test A', text: 'Do task A'),
        (name: 'Test B', text: 'Do task B'),
      ];
      await SettingsService.setPromptTemplates(saved);
      final loaded = SettingsService.promptTemplates;
      expect(loaded.length, 2);
      expect(loaded[0].name, 'Test A');
      expect(loaded[0].text, 'Do task A');
      expect(loaded[1].name, 'Test B');
      expect(loaded[1].text, 'Do task B');
    });

    test('ignores entries without tab separator', () async {
      SharedPreferences.setMockInitialValues({
        'prompt_templates': ['no-tab-here', 'valid\tentry'],
      });
      await SettingsService.init();
      final templates = SettingsService.promptTemplates;
      expect(templates.length, 1);
      expect(templates.first.name, 'valid');
      expect(templates.first.text, 'entry');
    });
  });

  group('PromptTemplatesDialog widget', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(body: child),
        );

    testWidgets('shows default templates on first open', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        wrap(Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => PromptTemplatesDialog.show(ctx, sent.add),
          child: const Text('Open'),
        ))),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Prompt Templates'), findsOneWidget);
      // 5 default templates should be visible
      expect(find.text('Review code'), findsOneWidget);
      expect(find.text('Write tests'), findsOneWidget);
      expect(find.text('Explain this'), findsOneWidget);
    });

    testWidgets('send button closes dialog and calls onSend', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        wrap(Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => PromptTemplatesDialog.show(ctx, sent.add),
          child: const Text('Open'),
        ))),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send').first);
      await tester.pumpAndSettle();

      expect(find.text('Prompt Templates'), findsNothing); // dialog closed
      expect(sent, isNotEmpty);
      expect(sent.first, endsWith('\r'));
    });

    testWidgets('add template form saves new template', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        wrap(Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => PromptTemplatesDialog.show(ctx, sent.add),
          child: const Text('Open'),
        ))),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Template'));
      await tester.pumpAndSettle();

      // First TextField = name, second = text
      await tester.enterText(find.byType(TextField).at(0), 'My Template');
      await tester.enterText(find.byType(TextField).at(1), 'Do something great');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('My Template'), findsOneWidget);
      final saved = SettingsService.promptTemplates;
      expect(saved.any((t) => t.name == 'My Template'), isTrue);
    });

    testWidgets('cancel in add form discards input', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        wrap(Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => PromptTemplatesDialog.show(ctx, sent.add),
          child: const Text('Open'),
        ))),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Template'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Discarded');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discarded'), findsNothing);
      expect(find.text('Add Template'), findsOneWidget);
    });
  });
}
