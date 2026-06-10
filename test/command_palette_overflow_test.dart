import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/l10n/app_localizations.dart';
import 'package:claude_code_cli_flutter/models/session_template.dart';
import 'package:claude_code_cli_flutter/widgets/command_palette.dart';

SessionTemplate _tpl(int i) => SessionTemplate(
      id: 'id-$i',
      name: 'Template number $i',
      agentId: 'claude',
      prompt: 'Do task $i with a reasonably long prompt body here.',
      createdAt: DateTime(2026, 1, 1),
    );

/// Mirrors production: the palette is shown via showDialog with a transparent
/// barrier and NO Dialog/Scaffold wrapper — so it must supply its own Material
/// ancestor. The launch button is wrapped in a Scaffold; the palette is not.
Widget _host(List<SessionTemplate> templates) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierColor: Colors.transparent,
              builder: (_) => CommandPalette(
                sessions: const [],
                agents: const [],
                onOpenSession: (_) {},
                onNewTask: () {},
                onRescan: () {},
                onOpenSettings: () {},
                templates: templates,
                onLaunchTemplate: (_) {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<void> _openPalette(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders without a Material ancestor error', (tester) async {
    await tester.pumpWidget(_host([_tpl(1)]));
    await _openPalette(tester);
    // A missing-Material assertion would surface here.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('does not overflow with a large result set', (tester) async {
    // 60 templates → far more entries than fit in the 480px palette.
    await tester.pumpWidget(_host(List.generate(60, _tpl)));
    await _openPalette(tester);

    // A RenderFlex overflow surfaces as a thrown exception during layout.
    expect(tester.takeException(), isNull);

    // The capped scroll region keeps the palette within the dialog bounds.
    final paletteHeight = tester.getSize(find.byType(ListView)).height;
    expect(paletteHeight, lessThanOrEqualTo(420));
  });

  testWidgets('stays short for a small result set', (tester) async {
    await tester.pumpWidget(_host([_tpl(1), _tpl(2)]));
    await _openPalette(tester);
    expect(tester.takeException(), isNull);
    final paletteHeight = tester.getSize(find.byType(ListView)).height;
    expect(paletteHeight, lessThan(420));
  });
}
