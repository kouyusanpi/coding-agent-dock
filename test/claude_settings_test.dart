import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/models/claude_settings.dart';

void main() {
  group('ClaudeSettings.toArgs', () {
    test('defaults produce model + effort only', () {
      const settings = ClaudeSettings();
      expect(settings.toArgs(), ['--model', 'opus', '--effort', 'high']);
    });

    test('includes permission mode, print and output format when set', () {
      const settings = ClaudeSettings(
        model: 'sonnet',
        effort: ClaudeEffort.medium,
        permissionMode: ClaudePermissionMode.acceptEdits,
        printMode: true,
        outputFormat: ClaudeOutputFormat.json,
      );
      expect(settings.toArgs(), [
        '--model', 'sonnet',
        '--effort', 'medium',
        '--permission-mode', 'acceptEdits',
        '--print',
        '--output-format', 'json',
      ]);
    });

    test('round-trips through JSON', () {
      const settings = ClaudeSettings(
        model: 'sonnet',
        effort: ClaudeEffort.xhigh,
        dangerouslySkipPermissions: true,
        extraFlags: ['--verbose'],
      );
      final restored = ClaudeSettings.fromJson(settings.toJson());
      expect(restored.toArgs(), settings.toArgs());
    });

    test('effort falls back to the default (high) on unknown value', () {
      expect(ClaudeEffort.from('bogus'), ClaudeEffort.high);
      expect(ClaudeEffort.from(null), ClaudeEffort.high);
    });
  });
}
