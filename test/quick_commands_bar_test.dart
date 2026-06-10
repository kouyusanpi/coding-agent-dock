import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/widgets/quick_commands_bar.dart';

void main() {
  Widget host(ValueChanged<String> onSend) => MaterialApp(
        home: Scaffold(body: QuickCommandsBar(onSend: onSend)),
      );

  testWidgets('renders all quick commands', (tester) async {
    await tester.pumpWidget(host((_) {}));
    for (final cmd in QuickCommandsBar.commands) {
      expect(find.text(cmd), findsOneWidget);
    }
  });

  testWidgets('tapping a chip sends the command with trailing Enter',
      (tester) async {
    String? sent;
    await tester.pumpWidget(host((s) => sent = s));

    await tester.tap(find.text('/context'));
    expect(sent, '/context\r');
  });

  testWidgets('each chip sends its own command', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(host(sent.add));

    await tester.tap(find.text('/model'));
    await tester.tap(find.text('/compact'));
    expect(sent, ['/model\r', '/compact\r']);
  });
}
