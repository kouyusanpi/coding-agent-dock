import 'dart:async';

import 'package:flutter/material.dart';

import '../models/agent_cli.dart';
import '../models/session_template.dart';
import '../services/session_template_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog for viewing, renaming, and deleting session templates.
class TemplateManagerDialog extends StatefulWidget {
  final List<AgentCli> agents;
  final void Function(SessionTemplate) onLaunch;

  const TemplateManagerDialog({
    super.key,
    required this.agents,
    required this.onLaunch,
  });

  static Future<void> show(
    BuildContext context, {
    required List<AgentCli> agents,
    required void Function(SessionTemplate) onLaunch,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) =>
          TemplateManagerDialog(agents: agents, onLaunch: onLaunch),
    );
  }

  @override
  State<TemplateManagerDialog> createState() => _TemplateManagerDialogState();
}

class _TemplateManagerDialogState extends State<TemplateManagerDialog> {
  List<SessionTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await SessionTemplateService.load();
    if (mounted) setState(() { _templates = t; _loading = false; });
  }

  String _agentName(String id) =>
      widget.agents.firstWhere((a) => a.id == id,
          orElse: () => AgentCli(
              id: id, displayName: id, binaryName: id,
              lastChecked: DateTime(2026))).displayName;

  Future<void> _delete(SessionTemplate template) async {
    await SessionTemplateService.delete(template.id);
    if (mounted) setState(() => _templates.removeWhere((t) => t.id == template.id));
  }

  Future<void> _rename(SessionTemplate template) async {
    final ctl = TextEditingController(text: template.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border700),
        ),
        title: Text('Rename template', style: AppTypography.cardTitle),
        content: TextField(
          controller: ctl,
          autofocus: true,
          style: AppTypography.body.copyWith(color: AppColors.text100),
          decoration: InputDecoration(
            hintText: 'Template name',
            hintStyle: AppTypography.meta,
            filled: true,
            fillColor: AppColors.bg900,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border800),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.accent400),
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.of(ctx).pop(v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.text400),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctl.text.trim();
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent400,
              foregroundColor: AppColors.bg950,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    final updated = template.copyWith(name: newName);
    await SessionTemplateService.update(updated);
    if (mounted) {
      setState(() {
        final idx = _templates.indexWhere((t) => t.id == template.id);
        if (idx >= 0) _templates[idx] = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.bookmark_outlined,
                    size: 18, color: AppColors.labelYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Saved Templates', style: AppTypography.cardTitle),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.text400,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            const Divider(color: AppColors.border700, height: 1),

            // Body
            Flexible(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent400, strokeWidth: 2))
                  : _templates.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark_border,
                                  size: 40, color: AppColors.text500),
                              const SizedBox(height: 12),
                              Text('No saved templates yet',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.text400)),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Save template" in the New Task dialog to save a reusable configuration.',
                                style: AppTypography.meta,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _templates.length,
                          itemBuilder: (context, i) =>
                              _TemplateRow(
                                template: _templates[i],
                                agentName: _agentName(_templates[i].agentId),
                                onLaunch: () {
                                  Navigator.of(context).pop();
                                  widget.onLaunch(_templates[i]);
                                },
                                onRename: () => _rename(_templates[i]),
                                onDelete: () => _delete(_templates[i]),
                              ),
                        ),
            ),

            // Footer hint
            if (!_loading && _templates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Tip: open templates quickly with ⌘K',
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

class _TemplateRow extends StatefulWidget {
  final SessionTemplate template;
  final String agentName;
  final VoidCallback onLaunch;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TemplateRow({
    required this.template,
    required this.agentName,
    required this.onLaunch,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends State<_TemplateRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppSpacing.normalTransition,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.bg800 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.sidebarItemRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmark_outline,
                size: 15, color: AppColors.labelYellow),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.template.name,
                      style: AppTypography.body
                          .copyWith(color: AppColors.text200),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Text(widget.agentName, style: AppTypography.meta),
                    if (widget.template.workingDirectory != null) ...[
                      Text('  ·  ', style: AppTypography.meta),
                      Flexible(
                        child: Text(
                          widget.template.workingDirectory!
                              .split('/')
                              .last,
                          style: AppTypography.meta,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ]),
                  if (widget.template.prompt.isNotEmpty)
                    Text(
                      widget.template.prompt,
                      style: AppTypography.mono.copyWith(
                          fontSize: 10, color: AppColors.text500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action buttons — always visible on hover, compact otherwise
            if (_hovered) ...[
              _iconBtn(Icons.play_arrow_outlined, 'Launch', widget.onLaunch,
                  AppColors.emerald500),
              _iconBtn(Icons.edit_outlined, 'Rename', widget.onRename,
                  AppColors.text400),
              _iconBtn(Icons.delete_outline, 'Delete', widget.onDelete,
                  AppColors.red400),
            ] else
              _iconBtn(Icons.play_arrow_outlined, 'Launch', widget.onLaunch,
                  AppColors.text500),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, String tooltip, VoidCallback onTap, Color color) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
