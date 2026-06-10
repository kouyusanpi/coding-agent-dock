import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Per-agent statistics computed from the session database.
class _AgentStats {
  final String agentId;
  final String agentName;
  final int total;
  final int completed;
  final int failed;
  final int totalDurationMs;

  _AgentStats({
    required this.agentId,
    required this.agentName,
    required this.total,
    required this.completed,
    required this.failed,
    required this.totalDurationMs,
  });

  int get avgDurationMs => total == 0 ? 0 : totalDurationMs ~/ total;
}

/// Dialog showing session statistics grouped by agent.
class SessionStatsDialog extends StatelessWidget {
  final List<AgentCli> agents;

  const SessionStatsDialog({super.key, required this.agents});

  static Future<void> show(BuildContext context,
      {required List<AgentCli> agents}) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => SessionStatsDialog(agents: agents),
    );
  }

  String _fmt(int? ms) {
    if (ms == null || ms == 0) return '—';
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    return '${m}m ${s}s';
  }

  List<_AgentStats> _compute(List<TaskSession> sessions) {
    final map = <String, _AgentStats>{};
    for (final s in sessions) {
      final id = s.agentCliId;
      final name = agents
          .firstWhere((a) => a.id == id,
              orElse: () => AgentCli(
                  id: id,
                  displayName: id,
                  binaryName: id,
                  lastChecked: DateTime.now()))
          .displayName;
      final prev = map[id];
      map[id] = _AgentStats(
        agentId: id,
        agentName: name,
        total: (prev?.total ?? 0) + 1,
        completed: (prev?.completed ?? 0) + (s.status == 'completed' ? 1 : 0),
        failed: (prev?.failed ?? 0) +
            (s.status == 'failed' || s.status == 'cancelled' ? 1 : 0),
        totalDurationMs:
            (prev?.totalDurationMs ?? 0) + (s.durationMs ?? 0),
      );
    }
    final list = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.bar_chart_outlined,
                    size: 18, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l10n.statsTitle,
                        style: AppTypography.cardTitle)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.text400,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            const Divider(color: AppColors.border700, height: 1),

            // Stats content
            StreamBuilder<List<TaskSession>>(
              stream: db.watchAllSessions(),
              builder: (context, snap) {
                final sessions = snap.data ?? [];
                if (sessions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.noStatsYet,
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center),
                  );
                }
                final stats = _compute(sessions);
                final grandTotal = sessions
                    .fold<int>(0, (s, e) => s + (e.durationMs ?? 0));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: _header(l10n),
                    ),
                    const Divider(color: AppColors.border800, height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          children: stats
                              .map((s) => _row(s))
                              .toList(),
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.border700, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: Row(children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: AppColors.text500),
                        const SizedBox(width: 6),
                        Text(
                          '${l10n.statsTotalTime}: ${_fmt(grandTotal)}',
                          style: AppTypography.meta,
                        ),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) => Row(children: [
        Expanded(
            child: Text(l10n.statsAgent,
                style: AppTypography.label)),
        _col(l10n.statsTotal, accent: false),
        _col(l10n.statsDone, accent: false),
        _col(l10n.statsFailed, accent: false),
        _col(l10n.statsAvgTime, accent: false, wide: true),
      ]);

  Widget _row(_AgentStats s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
            child: Text(s.agentName,
                style: AppTypography.body,
                overflow: TextOverflow.ellipsis),
          ),
          _col('${s.total}'),
          _col('${s.completed}',
              color: s.completed > 0 ? AppColors.emerald500 : null),
          _col('${s.failed}',
              color: s.failed > 0 ? AppColors.red400 : null),
          _col(_fmt(s.avgDurationMs == 0 ? null : s.avgDurationMs),
              wide: true),
        ]),
      );

  Widget _col(String text,
      {bool accent = false,
      Color? color,
      bool wide = false}) =>
      SizedBox(
        width: wide ? 72 : 48,
        child: Text(
          text,
          style: AppTypography.monoSmall.copyWith(
            color: color ??
                (accent ? AppColors.accent400 : AppColors.text400),
          ),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
