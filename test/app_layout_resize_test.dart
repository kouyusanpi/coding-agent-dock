import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claude_code_cli_flutter/services/settings_service.dart';
import 'package:claude_code_cli_flutter/theme/app_spacing.dart';
import 'package:claude_code_cli_flutter/widgets/app_layout.dart';

Widget _app() => MaterialApp(
      home: AppLayout(
        sidebar: const ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(key: Key('sidebar_content')),
        ),
        header: const SizedBox.shrink(),
        body: const SizedBox.expand(),
        constrainContent: false,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  testWidgets('sidebar starts at the default width', (tester) async {
    await tester.pumpWidget(_app());
    final size = tester.getSize(find.byKey(const Key('sidebar_content')));
    expect(size.width, AppSpacing.sidebarWidth);
  });

  testWidgets('dragging the divider widens the sidebar and persists',
      (tester) async {
    await tester.pumpWidget(_app());

    await tester.drag(
        find.byKey(AppLayout.dividerKey), const Offset(100, 0));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byKey(const Key('sidebar_content')));
    expect(size.width, AppSpacing.sidebarWidth + 100);
    expect(SettingsService.sidebarWidth, AppSpacing.sidebarWidth + 100);
  });

  testWidgets('sidebar width is clamped to the minimum', (tester) async {
    await tester.pumpWidget(_app());

    await tester.drag(
        find.byKey(AppLayout.dividerKey), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byKey(const Key('sidebar_content')));
    expect(size.width, AppLayout.minSidebarWidth);
  });

  testWidgets('saved width is restored on next build', (tester) async {
    await SettingsService.setSidebarWidth(320);
    await tester.pumpWidget(_app());

    final size = tester.getSize(find.byKey(const Key('sidebar_content')));
    expect(size.width, 320);
  });
}
