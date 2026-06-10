import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/models/agent_cli.dart';
import 'package:coding_agent_dock/services/cli_update_service.dart';

AgentCli _cli({String? npmPackage, String? pipPackage}) => AgentCli(
      id: 'test',
      displayName: 'Test',
      binaryName: 'test',
      lastChecked: DateTime(2026),
      npmPackage: npmPackage,
      pipPackage: pipPackage,
    );

void main() {
  group('CliUpdateService.isNewer', () {
    test('returns true when major is higher', () {
      expect(CliUpdateService.isNewer('1.0.0', '2.0.0'), isTrue);
    });

    test('returns true when minor is higher', () {
      expect(CliUpdateService.isNewer('1.2.0', '1.3.0'), isTrue);
    });

    test('returns true when patch is higher', () {
      expect(CliUpdateService.isNewer('1.2.3', '1.2.4'), isTrue);
    });

    test('returns false when versions are equal', () {
      expect(CliUpdateService.isNewer('1.2.3', '1.2.3'), isFalse);
    });

    test('returns false when current is newer', () {
      expect(CliUpdateService.isNewer('2.0.0', '1.9.9'), isFalse);
    });

    test('strips leading v prefix', () {
      expect(CliUpdateService.isNewer('v1.0.0', 'v2.0.0'), isTrue);
      expect(CliUpdateService.isNewer('v2.0.0', 'v1.0.0'), isFalse);
    });

    test('ignores pre-release suffixes', () {
      expect(CliUpdateService.isNewer('1.0.0-beta.1', '1.0.1'), isTrue);
      expect(CliUpdateService.isNewer('1.0.1', '1.0.0-beta.1'), isFalse);
    });

    test('handles two-part versions', () {
      expect(CliUpdateService.isNewer('1.0', '1.1'), isTrue);
      expect(CliUpdateService.isNewer('1.1', '1.0'), isFalse);
    });
  });

  group('CliUpdateService.updateCommand', () {
    test('returns npm install command for npm packages', () {
      expect(
        CliUpdateService.updateCommand(
            _cli(npmPackage: '@anthropic-ai/claude-code')),
        'npm install -g @anthropic-ai/claude-code',
      );
    });

    test('returns pip upgrade command for pip packages', () {
      expect(
        CliUpdateService.updateCommand(_cli(pipPackage: 'aider-chat')),
        'pip install --upgrade aider-chat',
      );
    });

    test('returns empty string when no package registered', () {
      expect(CliUpdateService.updateCommand(_cli()), '');
    });

    test('npm takes precedence when both are set', () {
      expect(
        CliUpdateService.updateCommand(
            _cli(npmPackage: '@scope/pkg', pipPackage: 'somepkg')),
        'npm install -g @scope/pkg',
      );
    });
  });
}
