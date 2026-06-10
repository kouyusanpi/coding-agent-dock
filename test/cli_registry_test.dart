import 'package:flutter_test/flutter_test.dart';
import 'package:claude_code_cli_flutter/models/cli_registry.dart';

void main() {
  group('CliRegistry', () {
    final all = CliRegistry.createAll();

    test('contains at least 12 entries', () {
      expect(all.length, greaterThanOrEqualTo(12));
    });

    test('all entries have unique ids', () {
      final ids = all.map((c) => c.id).toList();
      final unique = ids.toSet();
      expect(ids.length, unique.length,
          reason: 'Duplicate CLI ids: ${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
    });

    test('all entries have non-empty required fields', () {
      for (final cli in all) {
        expect(cli.id, isNotEmpty, reason: '${cli.displayName} has empty id');
        expect(cli.displayName, isNotEmpty,
            reason: '${cli.id} has empty displayName');
        expect(cli.binaryName, isNotEmpty,
            reason: '${cli.id} has empty binaryName');
        expect(cli.versionFlag, isNotEmpty,
            reason: '${cli.id} has empty versionFlag');
        expect(cli.installHint, isNotEmpty,
            reason: '${cli.id} has empty installHint');
      }
    });

    test('known core CLIs are present', () {
      final ids = all.map((c) => c.id).toSet();
      expect(ids, containsAll(['claude', 'codex', 'gemini', 'aider']));
    });

    test('new CLIs are present', () {
      final ids = all.map((c) => c.id).toSet();
      expect(ids, containsAll(['amazon-q', 'interpreter', 'gpt-engineer']));
    });

    test('amazon-q uses q binary', () {
      final q = all.firstWhere((c) => c.id == 'amazon-q');
      expect(q.binaryName, 'q');
      expect(q.commonPaths, isNotEmpty);
    });

    test('interpreter uses --version flag', () {
      final interp = all.firstWhere((c) => c.id == 'interpreter');
      expect(interp.versionFlag, '--version');
      expect(interp.commonPaths.any((p) => p.contains('interpreter')), isTrue);
    });

    test('gpt-engineer uses gpte binary with alias', () {
      final gpte = all.firstWhere((c) => c.id == 'gpt-engineer');
      expect(gpte.binaryName, 'gpte');
      expect(gpte.aliases, contains('gpt-engineer'));
    });

    test('all commonPaths are non-empty strings', () {
      for (final cli in all) {
        for (final path in cli.commonPaths) {
          expect(path, isNotEmpty,
              reason: '${cli.id} has an empty path in commonPaths');
        }
      }
    });
  });
}
