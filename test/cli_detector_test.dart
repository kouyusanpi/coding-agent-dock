import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/models/agent_cli.dart';
import 'package:coding_agent_dock/services/cli_detector.dart';

AgentCli _makeCli(String id) => AgentCli(
      id: id,
      displayName: id,
      binaryName: 'nonexistent_binary_$id',
      lastChecked: DateTime.now(),
      commonPaths: [],
    );

void main() {
  group('CliDetector', () {
    test('detect returns not-found for a missing binary', () async {
      final cli = _makeCli('ghost');
      final result = await CliDetector.detect(cli);
      expect(result.detected, isFalse);
      expect(result.error, isNotNull);
    });

    test('detectAll fires onUpdate for each result', () async {
      final clis = [_makeCli('a'), _makeCli('b'), _makeCli('c')];
      final received = <String>[];

      await CliDetector.detectAll(
        clis,
        onUpdate: (r) => received.add(r.id),
      );

      expect(received, containsAll(['a', 'b', 'c']));
      expect(received.length, 3);
    });

    test('detectAll returns all results in registry order', () async {
      final clis = [_makeCli('x'), _makeCli('y')];
      final results = await CliDetector.detectAll(clis);
      expect(results.map((r) => r.id), equals(['x', 'y']));
    });

    test('detectAll without onUpdate still returns results', () async {
      final clis = [_makeCli('solo')];
      final results = await CliDetector.detectAll(clis);
      expect(results.length, 1);
      expect(results.first.id, 'solo');
    });

    test('finds a binary via PATH even with no commonPaths', () async {
      // `echo` exists at /bin/echo on every macOS/Linux box and is on PATH,
      // but is NOT in commonPaths — so it can only be found by the login-shell
      // PATH search. Proves detection no longer depends on a hardcoded list.
      final cli = AgentCli(
        id: 'echo-probe',
        displayName: 'echo',
        binaryName: 'echo',
        versionFlag: '--version',
        lastChecked: DateTime.now(),
        commonPaths: const [],
      );
      final result = await CliDetector.detect(cli);
      expect(result.detected, isTrue);
      expect(result.binaryPath, isNotNull);
      expect(result.binaryPath, endsWith('/echo'));
    });
  });
}
