import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claude_code_cli_flutter/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  group('workspace bookmark storage', () {
    test('returns empty list by default', () {
      expect(SettingsService.workspaceBookmarks, isEmpty);
    });

    test('persists a single bookmark', () async {
      await SettingsService.setWorkspaceBookmarks([
        (name: 'Flutter App', path: '/Users/test/flutter_app'),
      ]);

      final bookmarks = SettingsService.workspaceBookmarks;
      expect(bookmarks, hasLength(1));
      expect(bookmarks[0].name, 'Flutter App');
      expect(bookmarks[0].path, '/Users/test/flutter_app');
    });

    test('persists multiple bookmarks in order', () async {
      await SettingsService.setWorkspaceBookmarks([
        (name: 'Project A', path: '/code/a'),
        (name: 'Project B', path: '/code/b'),
        (name: 'Project C', path: '/code/c'),
      ]);

      final bookmarks = SettingsService.workspaceBookmarks;
      expect(bookmarks, hasLength(3));
      expect(bookmarks[0].name, 'Project A');
      expect(bookmarks[1].name, 'Project B');
      expect(bookmarks[2].name, 'Project C');
    });

    test('overwrites previous bookmarks on set', () async {
      await SettingsService.setWorkspaceBookmarks([
        (name: 'Old', path: '/old/path'),
      ]);
      await SettingsService.setWorkspaceBookmarks([
        (name: 'New', path: '/new/path'),
      ]);

      final bookmarks = SettingsService.workspaceBookmarks;
      expect(bookmarks, hasLength(1));
      expect(bookmarks[0].name, 'New');
      expect(bookmarks[0].path, '/new/path');
    });

    test('handles clearing all bookmarks', () async {
      await SettingsService.setWorkspaceBookmarks([
        (name: 'Test', path: '/test'),
      ]);
      await SettingsService.setWorkspaceBookmarks([]);
      expect(SettingsService.workspaceBookmarks, isEmpty);
    });

    test('preserves paths with spaces', () async {
      await SettingsService.setWorkspaceBookmarks([
        (name: 'My Projects', path: '/Users/alice/My Documents/code'),
      ]);

      final bookmarks = SettingsService.workspaceBookmarks;
      expect(bookmarks[0].name, 'My Projects');
      expect(bookmarks[0].path, '/Users/alice/My Documents/code');
    });
  });
}
