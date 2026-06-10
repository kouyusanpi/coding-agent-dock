import 'dart:async';

import 'package:flutter/material.dart';

import '../models/agent_cli.dart';
import '../models/pipeline_rule.dart';
import '../services/pipeline_rule_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog for viewing, creating, toggling, and deleting pipeline rules.
///
/// A pipeline rule causes AgentDock to automatically relay a finished
/// session's output to another agent — e.g. "after Claude Code exits
/// successfully, open a new Aider task with the same context".
class PipelineRulesDialog extends StatefulWidget {
  final List<AgentCli> agents;

  const PipelineRulesDialog({super.key, required this.agents});

  static Future<void> show(
    BuildContext context, {
    required List<AgentCli> agents,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => PipelineRulesDialog(agents: agents),
    );
  }

  @override
  State<PipelineRulesDialog> createState() => _PipelineRulesDialogState();
}

class _PipelineRulesDialogState extends State<PipelineRulesDialog> {
  List<PipelineRule> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await PipelineRuleService.load();
    if (mounted) setState(() { _rules = r; _loading = false; });
  }

  List<AgentCli> get _detectedAgents =>
      widget.agents.where((a) => a.detected).toList();

  String _agentName(String id) =>
      widget.agents
          .firstWhere((a) => a.id == id,
              orElse: () =>
                  AgentCli(id: id, displayName: id, binaryName: id, lastChecked: DateTime(2026)))
          .displayName;

  Future<void> _addRule() async {
    final agents = _detectedAgents;
    if (agents.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 detected agents to create a rule.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showDialog<({String source, String target, bool onSuccessOnly})>(
      context: context,
      builder: (ctx) => _AddRuleDialog(agents: agents),
    );
    if (result == null || !mounted) return;

    final rule = await PipelineRuleService.create(
      sourceAgentId: result.source,
      targetAgentId: result.target,
      onSuccessOnly: result.onSuccessOnly,
    );
    setState(() => _rules = [..._rules, rule]);
  }

  Future<void> _deleteRule(PipelineRule rule) async {
    await PipelineRuleService.delete(rule.id);
    if (mounted) setState(() => _rules.removeWhere((r) => r.id == rule.id));
  }

  Future<void> _toggleRule(PipelineRule rule) async {
    final updated = rule.copyWith(enabled: !rule.enabled);
    await PipelineRuleService.update(updated);
    if (mounted) {
      setState(() {
        final idx = _rules.indexWhere((r) => r.id == rule.id);
        if (idx >= 0) _rules[idx] = updated;
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.account_tree_outlined,
                    size: 18, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pipeline Rules', style: AppTypography.cardTitle),
                ),
                TextButton.icon(
                  onPressed: _addRule,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Rule'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent400,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 4),
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

            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'When a session finishes, automatically relay its output to another agent.',
                style: AppTypography.meta,
              ),
            ),

            // Body
            Flexible(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent400, strokeWidth: 2))
                  : _rules.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_tree_outlined,
                                  size: 40, color: AppColors.text500),
                              const SizedBox(height: 12),
                              Text('No pipeline rules yet',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.text400)),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Add Rule" to automatically relay sessions between agents.',
                                style: AppTypography.meta,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _addRule,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add your first rule'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent400,
                                  side: const BorderSide(
                                      color: AppColors.accent400),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _rules.length,
                          itemBuilder: (context, i) => _RuleRow(
                            rule: _rules[i],
                            sourceName: _agentName(_rules[i].sourceAgentId),
                            targetName: _agentName(_rules[i].targetAgentId),
                            onToggle: () => _toggleRule(_rules[i]),
                            onDelete: () => _deleteRule(_rules[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual rule row
// ---------------------------------------------------------------------------

class _RuleRow extends StatefulWidget {
  final PipelineRule rule;
  final String sourceName;
  final String targetName;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RuleRow({
    required this.rule,
    required this.sourceName,
    required this.targetName,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends State<_RuleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    final dimmed = !rule.enabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        opacity: dimmed ? 0.5 : 1.0,
        duration: AppSpacing.normalTransition,
        child: AnimatedContainer(
          duration: AppSpacing.normalTransition,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bg800 : Colors.transparent,
            borderRadius:
                BorderRadius.circular(AppSpacing.sidebarItemRadius),
          ),
          child: Row(
            children: [
              // Flow diagram: source → condition → target
              Expanded(
                child: Row(
                  children: [
                    _AgentChip(name: widget.sourceName),
                    const SizedBox(width: 6),
                    _ConditionBadge(onSuccessOnly: rule.onSuccessOnly),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward,
                        size: 13, color: AppColors.text500),
                    const SizedBox(width: 6),
                    _AgentChip(name: widget.targetName, isTarget: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Toggle enable/disable
              Tooltip(
                message: rule.enabled ? 'Disable rule' : 'Enable rule',
                waitDuration: const Duration(milliseconds: 400),
                child: InkWell(
                  onTap: widget.onToggle,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      rule.enabled
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      size: 18,
                      color: rule.enabled
                          ? AppColors.emerald500
                          : AppColors.text500,
                    ),
                  ),
                ),
              ),
              // Delete button — only on hover
              if (_hovered) ...[
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Delete rule',
                  waitDuration: const Duration(milliseconds: 400),
                  child: InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: AppColors.red400),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentChip extends StatelessWidget {
  final String name;
  final bool isTarget;
  const _AgentChip({required this.name, this.isTarget = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isTarget
            ? AppColors.accent400.withAlpha(20)
            : AppColors.bg800,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTarget
              ? AppColors.accent400.withAlpha(60)
              : AppColors.border700,
        ),
      ),
      child: Text(
        name,
        style: AppTypography.mono.copyWith(
          fontSize: 11,
          color: isTarget ? AppColors.accent400 : AppColors.text200,
        ),
      ),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  final bool onSuccessOnly;
  const _ConditionBadge({required this.onSuccessOnly});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: onSuccessOnly
            ? AppColors.emerald500.withAlpha(20)
            : AppColors.labelYellow.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: onSuccessOnly
              ? AppColors.emerald500.withAlpha(60)
              : AppColors.labelYellow.withAlpha(60),
        ),
      ),
      child: Text(
        onSuccessOnly ? 'on success' : 'always',
        style: AppTypography.mono.copyWith(
          fontSize: 10,
          color: onSuccessOnly ? AppColors.emerald500 : AppColors.labelYellow,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add-rule dialog
// ---------------------------------------------------------------------------

class _AddRuleDialog extends StatefulWidget {
  final List<AgentCli> agents;
  const _AddRuleDialog({required this.agents});

  @override
  State<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<_AddRuleDialog> {
  late String _sourceId;
  late String _targetId;
  bool _onSuccessOnly = true;

  @override
  void initState() {
    super.initState();
    _sourceId = widget.agents.first.id;
    _targetId = widget.agents.length > 1
        ? widget.agents[1].id
        : widget.agents.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final agents = widget.agents;
    return AlertDialog(
      backgroundColor: AppColors.bg800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border700),
      ),
      title: Row(children: [
        const Icon(Icons.account_tree_outlined,
            size: 16, color: AppColors.accent400),
        const SizedBox(width: 8),
        Text('New Pipeline Rule', style: AppTypography.cardTitle),
      ]),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source agent', style: AppTypography.meta),
            const SizedBox(height: 6),
            _AgentDropdown(
              agents: agents,
              value: _sourceId,
              onChanged: (v) => setState(() => _sourceId = v!),
            ),
            const SizedBox(height: 14),
            Text('Target agent', style: AppTypography.meta),
            const SizedBox(height: 6),
            _AgentDropdown(
              agents: agents,
              value: _targetId,
              onChanged: (v) => setState(() => _targetId = v!),
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.border700, height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Only on success', style: AppTypography.body),
                    Text(
                      'Relay only when source exits with code 0',
                      style: AppTypography.meta,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _onSuccessOnly,
                activeThumbColor: AppColors.accent400,
                activeTrackColor: AppColors.accent400,
                onChanged: (v) => setState(() => _onSuccessOnly = v),
              ),
            ]),
            if (_sourceId == _targetId)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 14, color: AppColors.labelYellow),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Source and target are the same agent.',
                      style: AppTypography.meta
                          .copyWith(color: AppColors.labelYellow),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.text400),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop((
              source: _sourceId,
              target: _targetId,
              onSuccessOnly: _onSuccessOnly,
            ));
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent400,
            foregroundColor: AppColors.bg950,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Create Rule'),
        ),
      ],
    );
  }
}

class _AgentDropdown extends StatelessWidget {
  final List<AgentCli> agents;
  final String value;
  final ValueChanged<String?> onChanged;

  const _AgentDropdown({
    required this.agents,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppColors.bg800,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bg900,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent400),
        ),
      ),
      style: AppTypography.body.copyWith(color: AppColors.text100),
      items: agents
          .map((a) => DropdownMenuItem(
                value: a.id,
                child: Row(children: [
                  Text(a.displayName),
                  if (!a.detected) ...[
                    const SizedBox(width: 6),
                    Text('(not installed)',
                        style: AppTypography.meta
                            .copyWith(color: AppColors.text500)),
                  ],
                ]),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
