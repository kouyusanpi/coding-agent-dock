import 'package:flutter/material.dart';

import '../models/workflow_definition.dart';
import '../models/workflow_run.dart';
import '../services/workflow_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Real-time monitoring dialog for an active workflow run.
class WorkflowRunDialog extends StatefulWidget {
  final WorkflowEngine engine;
  final WorkflowDefinition definition;

  const WorkflowRunDialog({super.key, required this.engine, required this.definition});

  static Future<void> show(
    BuildContext context, {
    required WorkflowEngine engine,
    required WorkflowDefinition definition,
  }) {
    return showDialog<void>(
      context: context, barrierDismissible: false, barrierColor: AppColors.black60,
      builder: (_) => WorkflowRunDialog(engine: engine, definition: definition),
    );
  }

  @override
  State<WorkflowRunDialog> createState() => _WorkflowRunDialogState();
}

class _WorkflowRunDialogState extends State<WorkflowRunDialog> {
  @override
  void initState() { super.initState(); widget.engine.addListener(_update); }
  @override
  void dispose() { widget.engine.removeListener(_update); super.dispose(); }
  void _update() { if (mounted) setState(() {}); }

  WorkflowRun? get _run => widget.engine.currentRun;

  @override
  Widget build(BuildContext context) {
    final run = _run;
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border800)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _header(run),
        const Divider(height: 1, color: AppColors.border800),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(children: widget.definition.nodes.asMap().entries.expand((e) {
            final i = e.key; final node = e.value;
            return [if (i > 0) _connector(node.id), _nodeCard(node, run)];
          }).toList()))),
        const Divider(height: 1, color: AppColors.border800),
        _footer(run),
      ])),
    );
  }

  Widget _header(WorkflowRun? run) => Padding(padding: const EdgeInsets.all(AppSpacing.cardPadding), child: Row(children: [
    const Icon(Icons.monitor_heart, color: AppColors.accent400, size: 20),
    const SizedBox(width: AppSpacing.sectionGap),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.definition.name, style: AppTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (run != null) Text(_statusLabel(run.status), style: AppTypography.badge.copyWith(color: _statusColor(run.status))),
    ])),
    if (run != null && !run.isFinished)
      TextButton.icon(onPressed: () => widget.engine.cancel(), icon: const Icon(Icons.stop, size: 14, color: AppColors.red400), label: const Text('Cancel', style: TextStyle(color: AppColors.red400, fontSize: 12)))
    else
      IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.text500), onPressed: () => Navigator.of(context).pop()),
  ]));

  Widget _connector(String nodeId) {
    final has = widget.definition.edges.any((e) => e.toNodeId == nodeId);
    return Container(width: 2, height: 16, color: has ? AppColors.border700 : AppColors.border800);
  }

  Widget _nodeCard(WorkflowNode node, WorkflowRun? run) {
    final state = run?.nodeRuns[node.id];
    final s = state?.status ?? NodeStatus.pending;
    final icon = switch (s) {
      NodeStatus.pending => Icons.circle_outlined, NodeStatus.waiting => Icons.hourglass_empty,
      NodeStatus.running => Icons.sync, NodeStatus.completed => Icons.check_circle,
      NodeStatus.failed => Icons.error, NodeStatus.skipped => Icons.skip_next,
    };
    final color = switch (s) {
      NodeStatus.pending => AppColors.text500, NodeStatus.waiting => AppColors.text400,
      NodeStatus.running => AppColors.accent400, NodeStatus.completed => AppColors.emerald500,
      NodeStatus.failed => AppColors.red400, NodeStatus.skipped => AppColors.text500,
    };
    final typeLabel = switch (node.type) {
      WorkflowNodeType.agentTask => node.cliId ?? 'agent',
      WorkflowNodeType.fork => 'fork', WorkflowNodeType.join => 'join',
    };

    return Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.sectionGap),
      decoration: BoxDecoration(color: AppColors.bg800, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: s == NodeStatus.running ? AppColors.accent500.withValues(alpha: 0.5) : AppColors.border800)),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sectionGap),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(node.name, style: AppTypography.body.copyWith(fontSize: 13, color: AppColors.text200), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.bg950, borderRadius: BorderRadius.circular(4)),
              child: Text(typeLabel, style: AppTypography.badge.copyWith(fontSize: 10))),
          ]),
          if (state != null) ...[const SizedBox(height: 2), Row(children: [
            Text(s.label, style: AppTypography.badge.copyWith(color: color, fontSize: 11)),
            if (state.duration != null) ...[const SizedBox(width: 8), Text(_fmtDur(state.duration!), style: AppTypography.badge.copyWith(fontSize: 11))],
            if (state.exitCode != null) ...[const SizedBox(width: 8), Text('exit ${state.exitCode}', style: AppTypography.badge.copyWith(color: state.exitCode == 0 ? AppColors.emerald500 : AppColors.red400, fontSize: 11))],
          ])],
        ])),
        if (s == NodeStatus.failed) IconButton(icon: const Icon(Icons.refresh, size: 16, color: AppColors.accent400), tooltip: 'Retry', onPressed: () => widget.engine.retryNode(node.id)),
      ]));
  }

  Widget _footer(WorkflowRun? run) {
    if (run == null) return const SizedBox.shrink();
    final done = run.completedNodeCount, total = run.totalNodeCount;
    final pct = total > 0 ? done / total : 0.0;
    return Padding(padding: const EdgeInsets.all(AppSpacing.cardPadding), child: Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: pct, backgroundColor: AppColors.bg800,
        color: run.isFinished ? (run.status == WorkflowRunStatus.completed ? AppColors.emerald500 : AppColors.red400) : AppColors.accent400, minHeight: 4)),
      const SizedBox(height: AppSpacing.sectionGap),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$done / $total nodes', style: AppTypography.bodySmall),
        if (run.isFinished) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close', style: TextStyle(fontSize: 12))),
      ]),
    ]));
  }

  String _statusLabel(WorkflowRunStatus s) => switch (s) {
    WorkflowRunStatus.running => 'Running...', WorkflowRunStatus.completed => 'Completed',
    WorkflowRunStatus.failed => 'Failed', WorkflowRunStatus.cancelled => 'Cancelled' };
  Color _statusColor(WorkflowRunStatus s) => switch (s) {
    WorkflowRunStatus.running => AppColors.accent400, WorkflowRunStatus.completed => AppColors.emerald500,
    WorkflowRunStatus.failed => AppColors.red400, WorkflowRunStatus.cancelled => AppColors.text500 };
  String _fmtDur(Duration d) => d.inMinutes > 0 ? '${d.inMinutes}m ${d.inSeconds % 60}s' : '${d.inSeconds}s';
}
