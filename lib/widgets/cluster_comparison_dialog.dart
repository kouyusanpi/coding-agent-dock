import 'package:flutter/material.dart';

import '../database/database.dart';
import '../services/terminal_sessions_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../l10n/app_localizations.dart';
import 'task_panel.dart' show statusDotColor;

/// Dialog that shows all sessions in a multi-agent cluster run side by side.
///
/// Opened by tapping the ×N cluster badge on any session row.
/// When [terminals] is provided, live PTY output tails are shown for running
/// sessions and update in real-time via AnimatedBuilder.
class ClusterComparisonDialog extends StatelessWidget {
  final List<TaskSession> sessions;
  final String Function(String cliId) agentNameOf;
  final void Function(TaskSession) onOpen;
  final TerminalSessionsController? terminals;

  const ClusterComparisonDialog({
    super.key,
    required this.sessions,
    required this.agentNameOf,
    required this.onOpen,
    this.terminals,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TaskSession> sessions,
    required String Function(String) agentNameOf,
    required void Function(TaskSession) onOpen,
    TerminalSessionsController? terminals,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => ClusterComparisonDialog(
        sessions: sessions,
        agentNameOf: agentNameOf,
        onOpen: onOpen,
        terminals: terminals,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Infer the task name from the first session's input or name.
    final taskHint = sessions.first.input?.trim().isNotEmpty == true
        ? sessions.first.input!.trim()
        : sessions.first.name;
    final clipped =
        taskHint.length > 60 ? '${taskHint.substring(0, 57)}…' : taskHint;

    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined,
                      size: 18, color: AppColors.accent400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.clusterRunTitle(sessions.length),
                          style: AppTypography.cardTitle,
                        ),
                        Text(
                          clipped,
                          style: AppTypography.meta,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.text400,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border700, height: 1),

            // --- Session rows ---
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sessions.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: AppColors.border700, height: 1),
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  return _ClusterSessionRow(
                    session: s,
                    agentName: agentNameOf(s.agentCliId),
                    terminals: terminals,
                    onOpen: () {
                      Navigator.of(context).pop();
                      onOpen(s);
                    },
                  );
                },
              ),
            ),

            // --- Footer summary ---
            const Divider(color: AppColors.border700, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  _StatChip(
                    count: sessions.where((s) => s.status == 'running').length,
                    label: l10n.statusRunning,
                    color: AppColors.emerald500,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    count:
                        sessions.where((s) => s.status == 'completed').length,
                    label: l10n.statusCompleted,
                    color: AppColors.accent400,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    count: sessions
                        .where((s) =>
                            s.status == 'failed' || s.status == 'cancelled')
                        .length,
                    label: l10n.statusFailed,
                    color: AppColors.red400,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterSessionRow extends StatefulWidget {
  final TaskSession session;
  final String agentName;
  final VoidCallback onOpen;
  final TerminalSessionsController? terminals;

  const _ClusterSessionRow({
    required this.session,
    required this.agentName,
    required this.onOpen,
    this.terminals,
  });

  @override
  State<_ClusterSessionRow> createState() => _ClusterSessionRowState();
}

class _ClusterSessionRowState extends State<_ClusterSessionRow> {
  bool _hovered = false;

  String _fmtDuration(int? ms) {
    if (ms == null) return '';
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final dot = statusDotColor(s.status);
    final hasOutput = s.output != null && s.output!.trim().isNotEmpty;
    final isRunningLive = s.status == 'running' && widget.terminals != null;

    Widget content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: AppSpacing.fastTransition,
          color: _hovered ? AppColors.bg800 : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  // Agent + detail
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.agentName,
                            style: AppTypography.body
                                .copyWith(color: AppColors.text100)),
                        if (s.durationMs != null)
                          Text(
                            '${s.status} · ${_fmtDuration(s.durationMs)}',
                            style: AppTypography.meta,
                          )
                        else
                          Text(s.status, style: AppTypography.meta),
                        if (!isRunningLive && hasOutput)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              s.output!.trim().replaceAll('\n', ' '),
                              style: AppTypography.meta
                                  .copyWith(color: AppColors.text500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Open button
                  if (_hovered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent400.withAlpha(30),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        border: Border.all(
                            color: AppColors.accent400.withAlpha(80)),
                      ),
                      child: Text(
                        'Open',
                        style: AppTypography.meta
                            .copyWith(color: AppColors.accent400),
                      ),
                    ),
                ],
              ),
              // Live output tail — shown only when the session is actively
              // running and we have a TerminalSessionsController to read from.
              if (isRunningLive) _LiveTail(terminals: widget.terminals!, sessionId: s.id),
            ],
          ),
        ),
      ),
    );

    // Wrap with AnimatedBuilder so the live tail rebuilds on every PTY event.
    if (isRunningLive) {
      return AnimatedBuilder(
        animation: widget.terminals!,
        builder: (context, _) => content,
      );
    }
    return content;
  }
}

/// Reads the last few lines of live PTY output from [terminals] for [sessionId].
/// Rebuilt by the parent AnimatedBuilder on every PTY event.
class _LiveTail extends StatelessWidget {
  final TerminalSessionsController terminals;
  final int sessionId;

  const _LiveTail({required this.terminals, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final tail = terminals.getOutputTail(sessionId, maxLines: 3);
    if (tail.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bg950,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border800),
        ),
        child: Text(
          tail,
          style: AppTypography.monoSmall.copyWith(color: AppColors.text400),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatChip(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        '$count $label',
        style: AppTypography.meta.copyWith(color: color),
      ),
    );
  }
}
