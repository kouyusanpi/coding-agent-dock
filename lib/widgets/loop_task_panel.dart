import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/agent_cli.dart';
import '../models/loop_task.dart';
import '../services/loop_task_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog for managing and running saved loop-task configurations.
///
/// A loop task runs the same prompt for a specified number of iterations,
/// spawning one session per iteration. Configurations are persisted locally
/// and can be reused across sessions.
class LoopTaskPanel extends StatefulWidget {
  final List<AgentCli> agents;
  final String? initialWorkingDirectory;

  /// Called when the user clicks Run. Receives the task to execute.
  /// The caller is responsible for actually spawning the sessions.
  final void Function(LoopTask task)? onRun;

  const LoopTaskPanel({
    super.key,
    required this.agents,
    this.initialWorkingDirectory,
    this.onRun,
  });

  static Future<void> show(
    BuildContext context, {
    required List<AgentCli> agents,
    String? initialWorkingDirectory,
    void Function(LoopTask task)? onRun,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => LoopTaskPanel(
        agents: agents,
        initialWorkingDirectory: initialWorkingDirectory,
        onRun: onRun,
      ),
    );
  }

  @override
  State<LoopTaskPanel> createState() => _LoopTaskPanelState();
}

class _LoopTaskPanelState extends State<LoopTaskPanel> {
  final _nameCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  int _loopCount = 3;
  String? _agentId;

  List<LoopTask> _saved = [];
  bool _loading = true;
  // id being edited; null = creating new
  String? _editingId;

  List<AgentCli> get _detected =>
      widget.agents.where((a) => a.detected).toList();

  @override
  void initState() {
    super.initState();
    _agentId = _detected.isNotEmpty ? _detected.first.id : null;
    _dirCtrl.text = widget.initialWorkingDirectory ?? '';
    _loadSaved();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final tasks = await LoopTaskService.loadAll();
    if (mounted) setState(() { _saved = tasks; _loading = false; });
  }

  void _startEdit(LoopTask task) {
    setState(() {
      _editingId = task.id;
      _nameCtrl.text = task.name;
      _promptCtrl.text = task.prompt;
      _loopCount = task.loopCount;
      _agentId = task.agentId;
      _dirCtrl.text = task.workingDirectory ?? '';
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
      _promptCtrl.clear();
      _loopCount = 3;
      _agentId = _detected.isNotEmpty ? _detected.first.id : null;
      _dirCtrl.text = widget.initialWorkingDirectory ?? '';
    });
  }

  bool get _formValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _promptCtrl.text.trim().isNotEmpty &&
      _agentId != null;

  Future<void> _save() async {
    if (!_formValid) return;
    final dir = _dirCtrl.text.trim();
    if (_editingId != null) {
      final idx = _saved.indexWhere((t) => t.id == _editingId);
      if (idx >= 0) {
        final updated = _saved[idx].copyWith(
          name: _nameCtrl.text.trim(),
          agentId: _agentId!,
          prompt: _promptCtrl.text.trim(),
          loopCount: _loopCount,
          workingDirectory: dir.isEmpty ? null : dir,
        );
        await LoopTaskService.update(updated);
      }
    } else {
      await LoopTaskService.create(
        name: _nameCtrl.text.trim(),
        agentId: _agentId!,
        prompt: _promptCtrl.text.trim(),
        loopCount: _loopCount,
        workingDirectory: dir.isEmpty ? null : dir,
      );
    }
    _resetForm();
    await _loadSaved();
  }

  Future<void> _saveAndRun() async {
    if (!_formValid) return;
    await _save();
    if (_saved.isNotEmpty) _run(_saved.first);
  }

  void _run(LoopTask task) {
    widget.onRun?.call(task);
    Navigator.of(context).pop();
  }

  Future<void> _delete(LoopTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg900,
        title: Text('Delete "${task.name}"?', style: AppTypography.cardTitle),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: AppColors.text400, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.text400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.red400)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LoopTaskService.delete(task.id);
    if (_editingId == task.id) _resetForm();
    await _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border800),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 580, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.border800),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildForm(),
                    if (!_loading && _saved.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border800),
                      const SizedBox(height: 12),
                      Text('Saved Tasks',
                          style: AppTypography.sectionHeader),
                      const SizedBox(height: 8),
                      ..._saved.map(_buildSavedCard),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent400, strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(children: [
        const Icon(Icons.loop, color: AppColors.accent400, size: 20),
        const SizedBox(width: AppSpacing.sectionGap),
        Text('Loop Tasks', style: AppTypography.cardTitle),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: AppColors.text500),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ]),
    );
  }

  Widget _buildForm() {
    final isEditing = _editingId != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note,
                  size: 14, color: AppColors.accent400),
              const SizedBox(width: 6),
              Text(
                isEditing ? 'Edit Task' : 'New Loop Task',
                style: AppTypography.body
                    .copyWith(color: AppColors.text200, fontSize: 13),
              ),
              if (isEditing) ...[
                const Spacer(),
                TextButton(
                  onPressed: _resetForm,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.text400,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Cancel edit',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Task name
          _fieldLabel('Task Name'),
          const SizedBox(height: 4),
          _textField(
            controller: _nameCtrl,
            hint: 'e.g. Refactor Auth Module',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Prompt
          _fieldLabel('Prompt'),
          const SizedBox(height: 4),
          _textField(
            controller: _promptCtrl,
            hint: 'The task prompt sent to the agent on each iteration…',
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Agent + Loop count row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Agent'),
                    const SizedBox(height: 4),
                    _agentDropdown(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Loop Count'),
                    const SizedBox(height: 4),
                    _loopCountStepper(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Working directory (optional)
          _fieldLabel('Working Directory (optional)'),
          const SizedBox(height: 4),
          _textField(
            controller: _dirCtrl,
            hint: '/path/to/project',
          ),
          const SizedBox(height: 14),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _formValid ? _save : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border700),
                  foregroundColor: AppColors.text400,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  minimumSize: Size.zero,
                ),
                child: const Text('Save', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _formValid ? _saveAndRun : null,
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Run', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCard(LoopTask task) {
    final isBeingEdited = _editingId == task.id;
    final agentName = widget.agents
        .where((a) => a.id == task.agentId)
        .map((a) => a.displayName)
        .firstOrNull ?? task.agentId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isBeingEdited
              ? AppColors.accent10
              : AppColors.bg800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isBeingEdited
                ? AppColors.accent400.withAlpha(100)
                : AppColors.border800,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.loop, size: 16, color: AppColors.accent400),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.name,
                          style: AppTypography.body.copyWith(
                              color: AppColors.text200, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _badge('×${task.loopCount}', AppColors.accent400),
                      const SizedBox(width: 4),
                      _badge(agentName, AppColors.emerald500),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.prompt,
                    style: AppTypography.meta
                        .copyWith(color: AppColors.text500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.workingDirectory != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      task.workingDirectory!,
                      style: AppTypography.meta.copyWith(
                          color: AppColors.text500, fontSize: 9,
                          fontFamily: 'Menlo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.play_arrow,
                  size: 18, color: AppColors.emerald500),
              tooltip: 'Run',
              onPressed: () => _run(task),
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.edit,
                  size: 14, color: AppColors.text400),
              tooltip: 'Edit',
              onPressed: () => _startEdit(task),
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  size: 14, color: AppColors.text500),
              tooltip: 'Delete',
              onPressed: () => _delete(task),
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: AppTypography.meta
            .copyWith(color: AppColors.text400, fontSize: 11),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          fontSize: 12, color: AppColors.text200, fontFamily: 'Menlo'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 12, color: AppColors.text500),
        filled: true,
        fillColor: AppColors.bg900,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent400),
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _agentDropdown() {
    final detected = _detected;
    if (detected.isEmpty) {
      return const Text('No agents detected',
          style: TextStyle(fontSize: 12, color: AppColors.text500));
    }
    // Ensure selected value is still valid.
    final validId = detected.any((a) => a.id == _agentId)
        ? _agentId
        : detected.first.id;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bg900,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border800),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validId,
          isExpanded: true,
          dropdownColor: AppColors.bg900,
          style: const TextStyle(fontSize: 12, color: AppColors.text200),
          iconSize: 16,
          iconEnabledColor: AppColors.text500,
          items: detected
              .map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.displayName,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text200)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _agentId = v),
        ),
      ),
    );
  }

  Widget _loopCountStepper() {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.bg900,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border800),
      ),
      child: Row(
        children: [
          _stepBtn(Icons.remove, () {
            if (_loopCount > 1) setState(() => _loopCount--);
          }),
          Expanded(
            child: Center(
              child: IntrinsicWidth(
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  controller:
                      TextEditingController(text: '$_loopCount'),
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.text200,
                      fontFamily: 'Menlo'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 1 && n <= 50) {
                      setState(() => _loopCount = n);
                    }
                  },
                ),
              ),
            ),
          ),
          _stepBtn(Icons.add, () {
            if (_loopCount < 50) setState(() => _loopCount++);
          }),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 28,
            child: Center(
              child: Icon(icon, size: 14, color: AppColors.text400),
            ),
          ),
        ),
      );

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600,
            fontFamily: 'Menlo',
          ),
        ),
      );
}
