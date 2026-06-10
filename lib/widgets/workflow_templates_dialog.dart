import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/agent_cli.dart';
import '../models/workflow_definition.dart';
import '../services/workflow_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'workflow_editor_dialog.dart';

/// Dialog for managing workflow templates.
class WorkflowTemplatesDialog extends StatefulWidget {
  final List<AgentCli> agents;
  final void Function(WorkflowDefinition def, String? workingDirectory)? onLaunch;

  const WorkflowTemplatesDialog({super.key, required this.agents, this.onLaunch});

  static Future<void> show(
    BuildContext context, {
    required List<AgentCli> agents,
    void Function(WorkflowDefinition def, String? workingDirectory)? onLaunch,
  }) {
    return showDialog<void>(
      context: context, barrierColor: AppColors.black60,
      builder: (_) => WorkflowTemplatesDialog(agents: agents, onLaunch: onLaunch),
    );
  }

  @override
  State<WorkflowTemplatesDialog> createState() => _WorkflowTemplatesDialogState();
}

class _WorkflowTemplatesDialogState extends State<WorkflowTemplatesDialog> {
  List<WorkflowDefinition> _defs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final d = await WorkflowService.load();
    if (mounted) setState(() { _defs = d; _loading = false; });
  }

  Future<void> _create() async {
    final r = await WorkflowEditorDialog.show(context, agents: widget.agents);
    if (r == null) return;
    await WorkflowService.create(name: r.name, description: r.description, nodes: r.nodes, edges: r.edges, defaultWorkingDirectory: r.defaultWorkingDirectory);
    await _load();
  }

  Future<void> _edit(WorkflowDefinition d) async {
    final r = await WorkflowEditorDialog.show(context, existing: d, agents: widget.agents);
    if (r == null) return;
    await WorkflowService.update(r);
    await _load();
  }

  Future<void> _delete(WorkflowDefinition d) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bg900,
      title: Text('Delete "${d.name}"?', style: AppTypography.cardTitle),
      content: const Text('Cannot be undone.', style: TextStyle(color: AppColors.text400, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: AppColors.text400))),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete', style: TextStyle(color: AppColors.red400))),
      ],
    ));
    if (ok != true) return;
    await WorkflowService.delete(d.id);
    await _load();
  }

  Future<void> _export(WorkflowDefinition d) async {
    final json = await WorkflowService.exportJson(d.id);
    final path = await FilePicker.saveFile(dialogTitle: 'Export Workflow', fileName: '${d.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.workflow.json', allowedExtensions: ['json']);
    if (path == null) return;
    await File(path).writeAsString(json);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path'), behavior: SnackBarBehavior.floating));
  }

  Future<void> _import() async {
    final r = await FilePicker.pickFiles(dialogTitle: 'Import Workflow', type: FileType.custom, allowedExtensions: ['json']);
    if (r == null || r.files.single.path == null) return;
    try {
      final content = await File(r.files.single.path!).readAsString();
      await WorkflowService.importJson(content);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border800)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _header(),
        const Divider(height: 1, color: AppColors.border800),
        Flexible(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.accent400)) : _defs.isEmpty ? _empty() : _list()),
      ])),
    );
  }

  Widget _header() => Padding(padding: const EdgeInsets.all(AppSpacing.cardPadding), child: Row(children: [
    const Icon(Icons.hub_outlined, color: AppColors.accent400, size: 20),
    const SizedBox(width: AppSpacing.sectionGap),
    Text('Workflow Templates', style: AppTypography.cardTitle),
    const Spacer(),
    TextButton.icon(onPressed: _import, icon: const Icon(Icons.file_download, size: 14), label: const Text('Import', style: TextStyle(fontSize: 12))),
    const SizedBox(width: 4),
    ElevatedButton.icon(onPressed: _create, icon: const Icon(Icons.add, size: 14), label: const Text('New', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent500, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
    const SizedBox(width: 4),
    IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.text500), onPressed: () => Navigator.of(context).pop()),
  ]));

  Widget _empty() => Padding(padding: const EdgeInsets.all(AppSpacing.contentPadding), child: Column(children: [
    const Icon(Icons.account_tree, size: 40, color: AppColors.text500),
    const SizedBox(height: AppSpacing.sectionGap),
    Text('No workflow templates yet.', style: AppTypography.body),
    const SizedBox(height: 4),
    Text('Create one to define multi-agent workflows.', style: AppTypography.bodySmall),
  ]));

  Widget _list() => ListView.separated(shrinkWrap: true, padding: const EdgeInsets.all(AppSpacing.cardPadding),
    itemCount: _defs.length, separatorBuilder: (_, _) => const SizedBox(height: 6),
    itemBuilder: (_, i) => _card(_defs[i]));

  Widget _card(WorkflowDefinition d) {
    final agents = d.nodes.where((n) => n.type == WorkflowNodeType.agentTask).length;
    return Container(padding: const EdgeInsets.all(AppSpacing.sectionGap),
      decoration: BoxDecoration(color: AppColors.bg800, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border800)),
      child: Row(children: [
        const Icon(Icons.account_tree, size: 18, color: AppColors.accent400),
        const SizedBox(width: AppSpacing.sectionGap),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: AppTypography.body.copyWith(fontSize: 13, color: AppColors.text200)),
          const SizedBox(height: 2),
          Text('$agents agents, ${d.nodes.length} nodes, ${d.edges.length} edges', style: AppTypography.badge),
          if (d.description != null && d.description!.isNotEmpty) ...[const SizedBox(height: 2),
            Text(d.description!, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)],
        ])),
        IconButton(icon: const Icon(Icons.play_arrow, size: 18, color: AppColors.emerald500), tooltip: 'Launch',
          onPressed: () { widget.onLaunch?.call(d, d.defaultWorkingDirectory); Navigator.of(context).pop(); }),
        IconButton(icon: const Icon(Icons.edit, size: 14, color: AppColors.text400), tooltip: 'Edit', onPressed: () => _edit(d)),
        IconButton(icon: const Icon(Icons.file_upload, size: 14, color: AppColors.text400), tooltip: 'Export', onPressed: () => _export(d)),
        IconButton(icon: const Icon(Icons.delete, size: 14, color: AppColors.text500), tooltip: 'Delete', onPressed: () => _delete(d)),
      ]));
  }
}
