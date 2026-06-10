import 'dart:io';

/// CPU + RSS snapshot for one session's process tree.
class ProcessStats {
  final double cpu;  // percentage (can exceed 100 on multi-core)
  final int rssKb;   // resident set size in kilobytes

  const ProcessStats({required this.cpu, required this.rssKb});

  String get cpuLabel => '${cpu.toStringAsFixed(0)}%';

  String get memLabel {
    if (rssKb >= 1024 * 1024) {
      return '${(rssKb / 1024 / 1024).toStringAsFixed(1)} GB';
    }
    if (rssKb >= 1024) {
      return '${(rssKb / 1024).toStringAsFixed(0)} MB';
    }
    return '$rssKb KB';
  }
}

/// Queries macOS `ps` to sample CPU and RSS for a set of PTY-shell root
/// PIDs and their direct child processes (the actual agent CLI binaries).
///
/// Results are returned as a map of sessionId → [ProcessStats] and are best
/// polled on a 2–3 s timer — `ps axo` on macOS is instantaneous.
class ProcessMonitorService {
  ProcessMonitorService._();

  /// Sample CPU + RSS for the given [sessionPids] (sessionId → PTY PID).
  ///
  /// Returns an empty map on any error so callers never need to handle
  /// exceptions. The returned map only contains entries for sessions whose
  /// PID or a direct child was found in the system process table.
  static Future<Map<int, ProcessStats>> poll(
      Map<int, int> sessionPids) async {
    if (sessionPids.isEmpty) return {};

    try {
      final result = await Process.run(
        'ps',
        ['axo', 'pid=,ppid=,%cpu=,rss='],
        runInShell: false,
      );
      if (result.exitCode != 0) return {};

      // Build pid → (ppid, cpu, rssKb) lookup from ps output.
      final table = <int, ({int ppid, double cpu, int rssKb})>{};
      for (final line in (result.stdout as String).split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 4) continue;
        final pid = int.tryParse(parts[0]);
        final ppid = int.tryParse(parts[1]);
        final cpu = double.tryParse(parts[2]);
        final rss = int.tryParse(parts[3]);
        if (pid != null && ppid != null && cpu != null && rss != null) {
          table[pid] = (ppid: ppid, cpu: cpu, rssKb: rss);
        }
      }

      // For each session, aggregate stats for root + direct children.
      final out = <int, ProcessStats>{};
      for (final entry in sessionPids.entries) {
        final sessionId = entry.key;
        final rootPid = entry.value;

        double totalCpu = 0;
        int totalRss = 0;

        final root = table[rootPid];
        if (root != null) {
          totalCpu += root.cpu;
          totalRss += root.rssKb;
        }

        for (final row in table.values) {
          if (row.ppid == rootPid) {
            totalCpu += row.cpu;
            totalRss += row.rssKb;
          }
        }

        if (totalRss > 0 || totalCpu > 0) {
          out[sessionId] = ProcessStats(cpu: totalCpu, rssKb: totalRss);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}
