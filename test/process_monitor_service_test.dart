import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/services/process_monitor_service.dart';

void main() {
  group('ProcessStats labels', () {
    test('cpuLabel shows integer percentage', () {
      expect(ProcessStats(cpu: 5.7, rssKb: 0).cpuLabel, '6%');
      expect(ProcessStats(cpu: 0.4, rssKb: 0).cpuLabel, '0%');
      expect(ProcessStats(cpu: 100.0, rssKb: 0).cpuLabel, '100%');
    });

    test('memLabel formats KB', () {
      expect(ProcessStats(cpu: 0, rssKb: 512).memLabel, '512 KB');
    });

    test('memLabel formats MB', () {
      expect(ProcessStats(cpu: 0, rssKb: 2048).memLabel, '2 MB');
      expect(ProcessStats(cpu: 0, rssKb: 153600).memLabel, '150 MB');
    });

    test('memLabel formats GB', () {
      expect(ProcessStats(cpu: 0, rssKb: 1024 * 1024).memLabel, '1.0 GB');
      expect(ProcessStats(cpu: 0, rssKb: 1024 * 1024 * 2).memLabel, '2.0 GB');
    });
  });

  group('ProcessMonitorService.poll', () {
    test('returns empty map when sessionPids is empty', () async {
      final result = await ProcessMonitorService.poll({});
      expect(result, isEmpty);
    });
  });
}
