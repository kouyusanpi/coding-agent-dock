import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/services/custom_cli_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomCliService', () {
    test('add creates a custom agent with prefixed id', () async {
      final cli = await CustomCliService.add(
        displayName: 'My Agent',
        binary: 'myagent',
      );
      expect(cli, isNotNull);
      expect(cli!.id, startsWith(CustomCliService.idPrefix));
      expect(cli.displayName, 'My Agent');
      expect(cli.binaryName, 'myagent');
      expect(cli.commonPaths, isEmpty);
      expect(CustomCliService.isCustom(cli), isTrue);
    });

    test('absolute path binary becomes a commonPath', () async {
      final cli = await CustomCliService.add(
        displayName: 'Path Agent',
        binary: '/usr/local/bin/pathagent',
      );
      expect(cli, isNotNull);
      expect(cli!.binaryName, 'pathagent');
      expect(cli.commonPaths, ['/usr/local/bin/pathagent']);
    });

    test('load returns previously added agents', () async {
      await CustomCliService.add(displayName: 'A', binary: 'agent-a');
      await CustomCliService.add(displayName: 'B', binary: 'agent-b');

      final loaded = await CustomCliService.load();
      expect(loaded, hasLength(2));
      expect(loaded.map((c) => c.binaryName), ['agent-a', 'agent-b']);
    });

    test('rejects duplicate binary names', () async {
      final first =
          await CustomCliService.add(displayName: 'A', binary: 'dup');
      final second =
          await CustomCliService.add(displayName: 'B', binary: 'dup');
      expect(first, isNotNull);
      expect(second, isNull);
    });

    test('rejects empty name or binary', () async {
      expect(
          await CustomCliService.add(displayName: '  ', binary: 'x'), isNull);
      expect(
          await CustomCliService.add(displayName: 'x', binary: ' '), isNull);
    });

    test('remove deletes only the matching custom agent', () async {
      final a = await CustomCliService.add(displayName: 'A', binary: 'aa');
      await CustomCliService.add(displayName: 'B', binary: 'bb');

      await CustomCliService.remove(a!.id);
      final loaded = await CustomCliService.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.binaryName, 'bb');
    });

    test('remove ignores built-in (non-custom) ids', () async {
      await CustomCliService.add(displayName: 'A', binary: 'aa');
      await CustomCliService.remove('claude');
      expect(await CustomCliService.load(), hasLength(1));
    });

    test('custom version flag is persisted', () async {
      final cli = await CustomCliService.add(
        displayName: 'V',
        binary: 'vagent',
        versionFlag: '-V',
      );
      expect(cli!.versionFlag, '-V');
      final loaded = await CustomCliService.load();
      expect(loaded.single.versionFlag, '-V');
    });

    test('blank version flag falls back to --version', () async {
      final cli = await CustomCliService.add(
        displayName: 'V',
        binary: 'vagent2',
        versionFlag: '  ',
      );
      expect(cli!.versionFlag, '--version');
    });
  });
}
