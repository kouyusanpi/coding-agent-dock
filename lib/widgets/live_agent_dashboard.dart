import 'dart:async';

import 'package:flutter/material.dart';

import '../services/process_monitor_service.dart';
import '../services/terminal_sessions_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'task_panel.dart' show statusDotColor;

/// Full-screen overlay showing all open terminals as live cards.
///
/// Opened with ⇧⌘D. Each card shows the agent name, session name,
/// working directory, live output tail, CPU/memory, and uptime.
/// Clicking a card navigates directly to that terminal.
class LiveAgentDashboard extends StatefulWidget {
  final TerminalSessionsController terminals;
  final void Function(int sessionId) onJumpTo;
  final void Function(int sessionId, String name) onInject;

  const LiveAgentDashboard({
    super.key,
    required this.terminals,
    required this.onJumpTo,
    required this.onInject,
  });

  static Future<void> show(
    BuildContext context, {
    required TerminalSessionsController terminals,
    required void Function(int) onJumpTo,
    required void Function(int, String) onInject,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => LiveAgentDashboard(
        terminals: terminals,
        onJumpTo: onJumpTo,
        onInject: onInject,
      ),
    );
  }

  @override
  State<LiveAgentDashboard> createState() => _LiveAgentDashboardState();
}

class _LiveAgentDashboardState extends State<LiveAgentDashboard> {
  Map<int, ProcessStats> _stats = {};
  Timer? _statsTimer;
  Timer? _outputTimer;

  @override
  void initState() {
    super.initState();
    _pollStats();
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollStats());
    // Output tails are read directly from the controller — no extra timer needed
    // but we still need to rebuild periodically while agents are running.
    _outputTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _outputTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollStats() async {
    final pids = widget.terminals.sessionPids;
    if (pids.isEmpty) return;
    final s = await ProcessMonitorService.poll(pids);
    if (mounted) setState(() => _stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.terminals.openTerminals;

    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.grid_view_outlined,
                    size: 18, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Agent Dashboard',
                    style: AppTypography.cardTitle,
                  ),
                ),
                _RunningBadge(count: open.where((t) => t.running).length),
                const SizedBox(width: 8),
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

            // --- Body ---
            Flexible(
              child: open.isEmpty
                  ? const _EmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.65,
                      ),
                      itemCount: open.length,
                      itemBuilder: (context, i) {
                        final term = open[i];
                        return _AgentCard(
                          term: term,
                          stats: _stats[term.sessionId],
                          isActive:
                              widget.terminals.activeId == term.sessionId,
                          outputTail: widget.terminals
                              .getOutputTail(term.sessionId, maxLines: 3),
                          onJump: () {
                            Navigator.of(context).pop();
                            widget.onJumpTo(term.sessionId);
                          },
                          onInject: () {
                            Navigator.of(context).pop();
                            widget.onInject(term.sessionId, term.sessionName);
                          },
                        );
                      },
                    ),
            ),

            // --- Footer ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                '${open.length} session${open.length == 1 ? '' : 's'} · ⇧⌘D to toggle · Click a card to jump',
                style: AppTypography.meta.copyWith(
                    color: AppColors.text500, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Running count badge
// ---------------------------------------------------------------------------

class _RunningBadge extends StatelessWidget {
  final int count;
  const _RunningBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.emerald500.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.emerald500.withAlpha(77)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
              color: AppColors.emerald500, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$count running',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.emerald500,
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view_outlined,
              size: 40, color: AppColors.text500),
          const SizedBox(height: 12),
          Text('No open sessions',
              style:
                  AppTypography.body.copyWith(color: AppColors.text400)),
          const SizedBox(height: 6),
          Text(
            'Start a new task with ⌘N to see agents here.',
            style: AppTypography.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual agent card
// ---------------------------------------------------------------------------

class _AgentCard extends StatefulWidget {
  final ActiveTerminal term;
  final ProcessStats? stats;
  final bool isActive;
  final String outputTail;
  final VoidCallback onJump;
  final VoidCallback onInject;

  const _AgentCard({
    required this.term,
    this.stats,
    required this.isActive,
    required this.outputTail,
    required this.onJump,
    required this.onInject,
  });

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  bool _hovered = false;

  String _folderName(String? path) {
    if (path == null || path.isEmpty) return '';
    final parts = path.split('/');
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => '');
  }

  String _uptimeLabel(DateTime? startedAt) {
    if (startedAt == null) return '';
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inHours >= 1) {
      return '${elapsed.inHours}h ${elapsed.inMinutes.remainder(60)}m';
    }
    if (elapsed.inMinutes >= 1) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds.remainder(60)}s';
    }
    return '${elapsed.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final term = widget.term;
    final status = term.effectiveStatus;
    final dotColor = statusDotColor(status);
    final isRunning = term.running;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onJump,
        child: AnimatedContainer(
          duration: AppSpacing.normalTransition,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.bg800
                : widget.isActive
                    ? AppColors.bg800.withAlpha(180)
                    : AppColors.bg800.withAlpha(100),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.accent400.withAlpha(120)
                  : _hovered
                      ? AppColors.border700
                      : AppColors.border700.withAlpha(120),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Top row: status dot, agent+session, actions ---
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          term.cli.displayName,
                          style: AppTypography.label
                              .copyWith(color: AppColors.text400),
                        ),
                        Text(
                          term.sessionName,
                          style: AppTypography.body
                              .copyWith(color: AppColors.text100),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_hovered && isRunning)
                    Tooltip(
                      message: 'Inject message',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: widget.onInject,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.send_outlined,
                              size: 14, color: AppColors.accent400),
                        ),
                      ),
                    ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Jump to session',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.open_in_new_outlined,
                      size: 13,
                      color: _hovered
                          ? AppColors.accent400
                          : AppColors.text500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // --- Meta row: dir · uptime · CPU · mem ---
              Wrap(
                spacing: 6,
                children: [
                  if (_folderName(term.workingDirectory).isNotEmpty)
                    _MetaChip(
                      icon: Icons.folder_outlined,
                      label: _folderName(term.workingDirectory),
                      color: AppColors.accent400,
                    ),
                  if (isRunning && term.startedAt != null)
                    _MetaChip(
                      icon: Icons.timer_outlined,
                      label: _uptimeLabel(term.startedAt),
                      color: AppColors.text400,
                    ),
                  if (isRunning && widget.stats != null) ...[
                    _MetaChip(
                      icon: Icons.memory_outlined,
                      label: widget.stats!.cpuLabel,
                      color: AppColors.emerald500,
                    ),
                    _MetaChip(
                      icon: Icons.storage_outlined,
                      label: widget.stats!.memLabel,
                      color: AppColors.text400,
                    ),
                  ],
                  if (!isRunning)
                    _MetaChip(
                      icon: Icons.check_circle_outline,
                      label: status,
                      color: status == 'completed'
                          ? AppColors.emerald500
                          : AppColors.red400,
                    ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(color: AppColors.border700, height: 1),
              const SizedBox(height: 6),

              // --- Live output tail ---
              Expanded(
                child: widget.outputTail.isEmpty
                    ? Text(
                        isRunning ? 'Waiting for output…' : 'No output captured.',
                        style: AppTypography.meta,
                      )
                    : Text(
                        widget.outputTail,
                        style: AppTypography.mono.copyWith(
                          fontSize: 10,
                          color: AppColors.text400,
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color.withAlpha(180)),
      const SizedBox(width: 3),
      Text(
        label,
        style: AppTypography.mono.copyWith(fontSize: 10, color: color),
      ),
    ]);
  }
}
