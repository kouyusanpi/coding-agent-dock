import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/agent_cli.dart';
import '../models/workflow_definition.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog for creating and editing workflow definitions.
class WorkflowEditorDialog extends StatefulWidget {
  final WorkflowDefinition? existing;
  final List<AgentCli> agents;

  const WorkflowEditorDialog({super.key, this.existing, required this.agents});

  static Future<WorkflowDefinition?> show(
    BuildContext context, {
    WorkflowDefinition? existing,
    required List<AgentCli> agents,
  }) {
    return showDialog<WorkflowDefinition>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => WorkflowEditorDialog(existing: existing, agents: agents),
    );
  }

  @override
  State<WorkflowEditorDialog> createState() => _WorkflowEditorDialogState();
}

class _WorkflowEditorDialogState extends State<WorkflowEditorDialog> {
  static const _uuid = Uuid();
  late List<WorkflowNode> _nodes;
  late List<WorkflowEdge> _edges;
  final List<String> _errors = [];
  late TextEditingController _nameCtl;
  late TextEditingController _descCtl;
  late TextEditingController _wdCtl;
  final Map<String, TextEditingController> _nameCtls = {};
  final Map<String, TextEditingController> _promptCtls = {};

  List<AgentCli> get _detected => widget.agents.where((a) => a.detected).toList();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nodes = List.of(e?.nodes ?? []);
    _edges = List.of(e?.edges ?? []);
    _nameCtl = TextEditingController(text: e?.name ?? '');
    _descCtl = TextEditingController(text: e?.description ?? '');
    _wdCtl = TextEditingController(text: e?.defaultWorkingDirectory ?? '');
    _syncCtls();
  }

  void _syncCtls() {
    for (final n in _nodes) {
      _nameCtls.putIfAbsent(n.id, () => TextEditingController(text: n.name));
      _promptCtls.putIfAbsent(n.id, () => TextEditingController(text: n.promptTemplate ?? ''));
    }
    final ids = _nodes.map((n) => n.id).toSet();
    _nameCtls.removeWhere((k, _) => !ids.contains(k));
    _promptCtls.removeWhere((k, _) => !ids.contains(k));
  }

  @override
  void dispose() {
    _nameCtl.dispose(); _descCtl.dispose(); _wdCtl.dispose();
    for (final c in _nameCtls.values) {
      c.dispose();
    }
    for (final c in _promptCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _validate() {
    _errors.clear();
    if (_nameCtl.text.trim().isEmpty) _errors.add('Name is required');
    if (_nodes.isEmpty) _errors.add('At least one node required');
    for (final n in _nodes) {
      if (n.type == WorkflowNodeType.agentTask && (n.cliId == null || n.cliId!.isEmpty)) {
        _errors.add('"${n.name}" has no agent');
      }
    }
    if (_nodes.isNotEmpty) {
      final tmp = WorkflowDefinition(id: 't', name: _nameCtl.text, nodes: _nodes, edges: _edges, createdAt: DateTime.now(), updatedAt: DateTime.now());
      _errors.addAll(tmp.validate());
    }
  }

  void _addNode(WorkflowNodeType type) {
    setState(() {
      _nodes.add(WorkflowNode(
        id: _uuid.v4(),
        name: '${type.name} ${_nodes.length + 1}',
        type: type,
        cliId: type == WorkflowNodeType.agentTask && _detected.isNotEmpty ? _detected.first.id : null,
      ));
      _syncCtls();
    });
  }

  void _removeNode(String id) {
    setState(() {
      _nodes.removeWhere((n) => n.id == id);
      _edges.removeWhere((e) => e.fromNodeId == id || e.toNodeId == id);
      _syncCtls();
    });
  }

  WorkflowDefinition _build() {
    final e = widget.existing;
    return WorkflowDefinition(
      id: e?.id ?? _uuid.v4(),
      name: _nameCtl.text.trim(),
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
      nodes: _nodes.map((n) => n.copyWith(
        name: _nameCtls[n.id]?.text ?? n.name,
        promptTemplate: (_promptCtls[n.id]?.text ?? '').isEmpty ? null : _promptCtls[n.id]!.text,
      )).toList(),
      edges: _edges,
      defaultWorkingDirectory: _wdCtl.text.trim().isEmpty ? null : _wdCtl.text.trim(),
      createdAt: e?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _validate();
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border800)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _header(),
          const Divider(height: 1, color: AppColors.border800),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.cardPadding), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _tf(_nameCtl, 'Workflow Name', hint: 'e.g. Plan \u2192 Code \u2192 Review'),
            const SizedBox(height: AppSpacing.sectionGap),
            _tf(_descCtl, 'Description (optional)', maxLines: 2),
            const SizedBox(height: AppSpacing.sectionGap),
            _tf(_wdCtl, 'Working Directory (optional)', hint: '/path/to/project'),
            const SizedBox(height: AppSpacing.cardPadding),
            _nodesSection(),
            const SizedBox(height: AppSpacing.cardPadding),
            _edgesSection(),
            if (_errors.isNotEmpty) ...[const SizedBox(height: AppSpacing.sectionGap), _errorBox()],
          ]))),
          const Divider(height: 1, color: AppColors.border800),
          _footer(),
        ]),
      ),
    );
  }

  Widget _header() => Padding(padding: const EdgeInsets.all(AppSpacing.cardPadding), child: Row(children: [
    const Icon(Icons.account_tree, color: AppColors.accent400, size: 20),
    const SizedBox(width: AppSpacing.sectionGap),
    Text(widget.existing != null ? 'Edit Workflow' : 'New Workflow', style: AppTypography.cardTitle),
    const Spacer(),
    IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.text500), onPressed: () => Navigator.of(context).pop()),
  ]));

  Widget _tf(TextEditingController ctl, String label, {String? hint, int maxLines = 1}) => TextField(
    controller: ctl, maxLines: maxLines, style: AppTypography.body,
    decoration: InputDecoration(labelText: label, labelStyle: AppTypography.label, hintText: hint, hintStyle: AppTypography.bodySmall,
      filled: true, fillColor: AppColors.bg800,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border800)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border800)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.accent500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
  );

  Widget _nodesSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text('Nodes', style: AppTypography.label),
      const Spacer(),
      PopupMenuButton<WorkflowNodeType>(
        icon: const Icon(Icons.add, size: 18, color: AppColors.accent400),
        color: AppColors.bg800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: AppColors.border700)),
        onSelected: _addNode,
        itemBuilder: (_) => const [
          PopupMenuItem(value: WorkflowNodeType.agentTask, child: Text('Agent Task', style: TextStyle(fontSize: 13))),
          PopupMenuItem(value: WorkflowNodeType.fork, child: Text('Fork (parallel)', style: TextStyle(fontSize: 13))),
          PopupMenuItem(value: WorkflowNodeType.join, child: Text('Join (wait all)', style: TextStyle(fontSize: 13))),
        ],
      ),
    ]),
    const SizedBox(height: AppSpacing.sectionGap),
    if (_nodes.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(color: AppColors.bg800, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border800)),
      child: Text('No nodes yet. Add an Agent Task to get started.', style: AppTypography.bodySmall, textAlign: TextAlign.center))
    else ..._nodes.map(_nodeCard),
  ]);

  Widget _nodeCard(WorkflowNode node) {
    final icon = switch (node.type) { WorkflowNodeType.agentTask => Icons.smart_toy, WorkflowNodeType.fork => Icons.call_split, WorkflowNodeType.join => Icons.merge_type };
    final label = switch (node.type) { WorkflowNodeType.agentTask => 'Agent Task', WorkflowNodeType.fork => 'Fork', WorkflowNodeType.join => 'Join' };
    return Container(margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap), padding: const EdgeInsets.all(AppSpacing.sectionGap),
      decoration: BoxDecoration(color: AppColors.bg800, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border800)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: AppColors.accent400), const SizedBox(width: 6), Text(label, style: AppTypography.badge),
          const Spacer(), IconButton(icon: const Icon(Icons.delete, size: 14, color: AppColors.text500), onPressed: () => _removeNode(node.id), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28))]),
        const SizedBox(height: 6),
        TextField(controller: _nameCtls[node.id], style: AppTypography.body.copyWith(fontSize: 13), decoration: _dec('Node name')),
        if (node.type == WorkflowNodeType.agentTask) ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(initialValue: node.cliId,
            items: _detected.map((a) => DropdownMenuItem(value: a.id, child: Text(a.displayName, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) { final i = _nodes.indexWhere((n) => n.id == node.id); if (i >= 0) setState(() => _nodes[i] = node.copyWith(cliId: v)); },
            dropdownColor: AppColors.bg800, decoration: _dec('Agent'), isDense: true, style: AppTypography.body.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _promptCtls[node.id], maxLines: 3, style: AppTypography.monoSmall,
            decoration: _dec('Prompt (use {{node:<id>:output}})')),
        ],
      ]));
  }

  Widget _edgesSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text('Edges', style: AppTypography.label),
      const Spacer(),
      IconButton(icon: const Icon(Icons.add, size: 18, color: AppColors.accent400), onPressed: _nodes.length >= 2 ? () => setState(() => _edges.add(WorkflowEdge(fromNodeId: _nodes.first.id, toNodeId: _nodes.last.id))) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
    ]),
    const SizedBox(height: AppSpacing.sectionGap),
    if (_edges.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.sectionGap),
      decoration: BoxDecoration(color: AppColors.bg800, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border800)),
      child: Text('No connections yet.', style: AppTypography.bodySmall, textAlign: TextAlign.center))
    else ..._edges.asMap().entries.map((e) => _edgeRow(e.key, e.value)),
  ]);

  Widget _edgeRow(int i, WorkflowEdge edge) => Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: AppColors.bg800, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border800)),
    child: Row(children: [
      Expanded(child: DropdownButtonFormField<String>(initialValue: _nodes.any((n) => n.id == edge.fromNodeId) ? edge.fromNodeId : null,
        items: _nodes.map((n) => DropdownMenuItem(value: n.id, child: Text(n.name, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (v) { if (v != null) setState(() => _edges[i] = edge.copyWith(fromNodeId: v)); },
        decoration: _dec('From'), isDense: true, style: const TextStyle(fontSize: 12, color: AppColors.text200), dropdownColor: AppColors.bg800)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: DropdownButton<EdgeCondition>(value: edge.condition,
        items: const [DropdownMenuItem(value: EdgeCondition.always, child: Text('always', style: TextStyle(fontSize: 11))),
          DropdownMenuItem(value: EdgeCondition.onSuccess, child: Text('on success', style: TextStyle(fontSize: 11))),
          DropdownMenuItem(value: EdgeCondition.onFailure, child: Text('on failure', style: TextStyle(fontSize: 11)))],
        onChanged: (v) { if (v != null) setState(() => _edges[i] = edge.copyWith(condition: v)); },
        dropdownColor: AppColors.bg800, isDense: true, underline: const SizedBox(), style: const TextStyle(fontSize: 11, color: AppColors.text400))),
      const Icon(Icons.arrow_forward, size: 14, color: AppColors.text500), const SizedBox(width: 6),
      Expanded(child: DropdownButtonFormField<String>(initialValue: _nodes.any((n) => n.id == edge.toNodeId) ? edge.toNodeId : null,
        items: _nodes.map((n) => DropdownMenuItem(value: n.id, child: Text(n.name, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (v) { if (v != null) setState(() => _edges[i] = edge.copyWith(toNodeId: v)); },
        decoration: _dec('To'), isDense: true, style: const TextStyle(fontSize: 12, color: AppColors.text200), dropdownColor: AppColors.bg800)),
      IconButton(icon: const Icon(Icons.close, size: 14, color: AppColors.text500), onPressed: () => setState(() => _edges.removeAt(i)), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
    ]));

  Widget _errorBox() => Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.sectionGap),
    decoration: BoxDecoration(color: AppColors.red400.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.red400.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: _errors.map((e) => Padding(padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [const Icon(Icons.warning, size: 12, color: AppColors.red400), const SizedBox(width: 4),
          Expanded(child: Text(e, style: AppTypography.badge.copyWith(color: AppColors.red400, fontSize: 11)))]))).toList()));

  Widget _footer() => Padding(padding: const EdgeInsets.all(AppSpacing.cardPadding), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: AppTypography.body.copyWith(color: AppColors.text400))),
    const SizedBox(width: AppSpacing.sectionGap),
    ElevatedButton(onPressed: _errors.isEmpty ? () => Navigator.of(context).pop(_build()) : null,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent500, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      child: const Text('Save', style: TextStyle(fontSize: 13))),
  ]));

  InputDecoration _dec(String l) => InputDecoration(labelText: l, labelStyle: AppTypography.label.copyWith(fontSize: 11),
    filled: true, fillColor: AppColors.bg950,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border800)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border800)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.accent500)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), isDense: true);
}
