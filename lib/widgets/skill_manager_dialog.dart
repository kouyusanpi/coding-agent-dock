import 'package:flutter/material.dart';

import '../models/skill.dart';
import '../services/skill_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Unified manager for Claude Code skill files (`SKILL.md`).
///
/// Lists global (`~/.claude/skills`) and — when a project working directory is
/// supplied — project (`<wd>/.claude/skills`) skills, and supports creating,
/// editing and deleting them. Open via [SkillManagerDialog.show].
class SkillManagerDialog extends StatefulWidget {
  /// Active session working directory, enabling project-scoped skills. When
  /// null only global skills are shown and new skills default to global.
  final String? workingDirectory;

  const SkillManagerDialog({super.key, this.workingDirectory});

  static Future<void> show(BuildContext context, {String? workingDirectory}) {
    return showDialog<void>(
      context: context,
      builder: (_) => SkillManagerDialog(workingDirectory: workingDirectory),
    );
  }

  @override
  State<SkillManagerDialog> createState() => _SkillManagerDialogState();
}

enum _Mode { list, edit }

class _SkillManagerDialogState extends State<SkillManagerDialog> {
  List<Skill> _skills = [];
  bool _loading = true;
  _Mode _mode = _Mode.list;

  // Edit/create form state.
  Skill? _editing; // null = creating new
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  SkillScope _scope = SkillScope.user;
  String? _formError;

  bool get _hasProject =>
      widget.workingDirectory != null && widget.workingDirectory!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final skills =
        await SkillService.listAll(workingDirectory: widget.workingDirectory);
    if (!mounted) return;
    setState(() {
      _skills = skills;
      _loading = false;
    });
  }

  void _startCreate() {
    setState(() {
      _editing = null;
      _nameCtl.text = '';
      _descCtl.text = '';
      _bodyCtl.text = _scaffoldBody;
      _scope = _hasProject ? _scope : SkillScope.user;
      _formError = null;
      _mode = _Mode.edit;
    });
  }

  void _startEdit(Skill skill) {
    setState(() {
      _editing = skill;
      _nameCtl.text = skill.name;
      _descCtl.text = skill.description;
      _bodyCtl.text = skill.body;
      _scope = skill.scope;
      _formError = null;
      _mode = _Mode.edit;
    });
  }

  Future<void> _saveForm() async {
    final name = _nameCtl.text.trim();
    final desc = _descCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Name is required.');
      return;
    }
    try {
      if (_editing == null) {
        await SkillService.create(
          name: name,
          description: desc,
          body: _bodyCtl.text,
          scope: _scope,
          workingDirectory: widget.workingDirectory,
        );
      } else {
        // Name/slug is fixed once created; update description + body in place.
        await SkillService.save(_editing!.copyWith(
          description: desc,
          body: _bodyCtl.text,
        ));
      }
      if (!mounted) return;
      setState(() => _mode = _Mode.list);
      await _reload();
    } on StateError catch (e) {
      setState(() => _formError = e.message);
    } catch (e) {
      setState(() => _formError = 'Could not save: $e');
    }
  }

  Future<void> _confirmDelete(Skill skill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg800,
        title: Text('Delete "${skill.name}"?',
            style: AppTypography.cardTitle),
        content: Text(
          'This permanently removes the skill folder and its SKILL.md.',
          style: AppTypography.body.copyWith(color: AppColors.text400),
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
    if (ok == true) {
      await SkillService.delete(skill);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const Divider(color: AppColors.border700, height: 1),
              Flexible(
                child: _mode == _Mode.list ? _listView() : _editView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final isEdit = _mode == _Mode.edit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(children: [
        Icon(isEdit ? Icons.edit_note : Icons.auto_awesome_outlined,
            size: 16, color: AppColors.accent400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isEdit
                ? (_editing == null ? 'New Skill' : 'Edit Skill')
                : 'Skills',
            style: AppTypography.cardTitle,
          ),
        ),
        if (isEdit)
          TextButton(
            onPressed: () => setState(() => _mode = _Mode.list),
            child: const Text('Back',
                style: TextStyle(color: AppColors.text400, fontSize: 12)),
          ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 16),
          color: AppColors.text400,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }

  Widget _listView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent400),
                    ),
                  ),
                )
              : _skills.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'No skills yet.\nClick "New Skill" to create one in ~/.claude/skills.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.text500, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _skills.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.border800, height: 1),
                      itemBuilder: (_, i) => _SkillRow(
                        skill: _skills[i],
                        onEdit: () => _startEdit(_skills[i]),
                        onDelete: () => _confirmDelete(_skills[i]),
                      ),
                    ),
        ),
        const Divider(color: AppColors.border700, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            TextButton.icon(
              onPressed: _startCreate,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('New Skill'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent400,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
            const Spacer(),
            Text('${_skills.length} skill${_skills.length == 1 ? '' : 's'}',
                style: AppTypography.meta),
          ]),
        ),
      ],
    );
  }

  Widget _editView() {
    final isNew = _editing == null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Name'),
          _field(
            controller: _nameCtl,
            hint: 'e.g. Code Review',
            enabled: isNew, // slug/folder is immutable after creation
            maxLines: 1,
          ),
          if (isNew)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Folder: ${Skill.slugify(_nameCtl.text)}/SKILL.md',
                  style: AppTypography.meta),
            ),
          const SizedBox(height: 12),
          _label('Description'),
          _field(
            controller: _descCtl,
            hint: 'What it does and when it triggers…',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          if (isNew && _hasProject) ...[
            _label('Location'),
            _scopeSelector(),
            const SizedBox(height: 12),
          ],
          _label('Instructions (Markdown)'),
          _field(
            controller: _bodyCtl,
            hint: '# Skill\n\nStep-by-step instructions…',
            maxLines: 10,
            mono: true,
          ),
          if (_formError != null) ...[
            const SizedBox(height: 10),
            Text(_formError!,
                style: AppTypography.meta.copyWith(color: AppColors.red400)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _mode = _Mode.list),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text400,
                  side: const BorderSide(color: AppColors.border700),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent400,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(isNew ? 'Create' : 'Save'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _scopeSelector() {
    return Row(children: [
      _scopeChip(SkillScope.user, 'Global', '~/.claude/skills'),
      const SizedBox(width: 8),
      _scopeChip(SkillScope.project, 'This project', '.claude/skills'),
    ]);
  }

  Widget _scopeChip(SkillScope scope, String label, String sub) {
    final selected = _scope == scope;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _scope = scope),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent10 : AppColors.bg800,
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            border: Border.all(
                color: selected ? AppColors.accent400 : AppColors.border800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.body.copyWith(
                      color: selected
                          ? AppColors.accent400
                          : AppColors.text200)),
              Text(sub, style: AppTypography.meta),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTypography.label),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    bool enabled = true,
    bool mono = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}), // refresh slug preview
      style: mono
          ? AppTypography.body.copyWith(fontFamily: 'Menlo', fontSize: 12)
          : AppTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.meta,
        filled: true,
        fillColor: enabled ? AppColors.bg800 : AppColors.bg900,
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
    );
  }

  static const _scaffoldBody = '# Skill\n\n'
      'Describe step-by-step what to do when this skill runs.\n';
}

class _SkillRow extends StatefulWidget {
  final Skill skill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SkillRow({
    required this.skill,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SkillRow> createState() => _SkillRowState();
}

class _SkillRowState extends State<_SkillRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isProject = widget.skill.scope == SkillScope.project;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: AppSpacing.fastTransition,
          color: _hovered ? AppColors.bg800 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(widget.skill.name,
                          style: AppTypography.body
                              .copyWith(color: AppColors.text100),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    _scopeBadge(isProject),
                  ]),
                  if (widget.skill.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.skill.description,
                      style: AppTypography.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: AppSpacing.fastTransition,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _iconBtn(Icons.edit_outlined, AppColors.text400, widget.onEdit),
                const SizedBox(width: 2),
                _iconBtn(
                    Icons.delete_outline, AppColors.red400, widget.onDelete),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _scopeBadge(bool isProject) {
    final color = isProject ? AppColors.emerald500 : AppColors.text500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isProject ? 'project' : 'global',
        style: TextStyle(
            fontFamily: 'Menlo', fontSize: 9, color: color),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
