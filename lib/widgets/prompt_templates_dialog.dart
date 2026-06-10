import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog that shows user-defined prompt templates.
///
/// Each template can be sent to the active terminal with one click.
/// Templates are persisted via [SettingsService.promptTemplates].
class PromptTemplatesDialog extends StatefulWidget {
  final ValueChanged<String> onSend;

  const PromptTemplatesDialog({super.key, required this.onSend});

  static Future<void> show(BuildContext context, ValueChanged<String> onSend) {
    return showDialog<void>(
      context: context,
      builder: (_) => PromptTemplatesDialog(onSend: onSend),
    );
  }

  @override
  State<PromptTemplatesDialog> createState() => _PromptTemplatesDialogState();
}

class _PromptTemplatesDialogState extends State<PromptTemplatesDialog> {
  late List<({String name, String text})> _templates;
  bool _adding = false;
  final _nameCtl = TextEditingController();
  final _textCtl = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _templates = List.from(SettingsService.promptTemplates);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _textCtl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await SettingsService.setPromptTemplates(_templates);
  }

  void _deleteAt(int index) {
    setState(() => _templates.removeAt(index));
    _save();
  }

  void _addTemplate() {
    final name = _nameCtl.text.trim();
    final text = _textCtl.text.trim();
    if (name.isEmpty || text.isEmpty) return;
    setState(() {
      _templates.add((name: name, text: text));
      _adding = false;
      _nameCtl.clear();
      _textCtl.clear();
    });
    _save();
  }

  void _send(String text) {
    Navigator.of(context).pop();
    widget.onSend('$text\r');
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
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.bolt_outlined,
                    size: 16, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Prompt Templates',
                      style: AppTypography.cardTitle),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.text400,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ]),
            ),
            const Divider(color: AppColors.border700, height: 1),

            // Template list
            Flexible(
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _templates.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No templates yet.\nClick "Add Template" to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.text500, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _templates.length,
                      separatorBuilder: (context, i) =>
                          const Divider(color: AppColors.border800, height: 1),
                      itemBuilder: (_, i) =>
                          _TemplateRow(
                            name: _templates[i].name,
                            text: _templates[i].text,
                            onSend: () => _send(_templates[i].text),
                            onDelete: () => _deleteAt(i),
                          ),
                    ),
            ),
            ),

            // Add template form
            if (_adding) ...[
              const Divider(color: AppColors.border700, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      controller: _nameCtl,
                      focusNode: _nameFocus,
                      hint: 'Template name (e.g. Review code)',
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _textCtl,
                      hint: 'Prompt text to send…',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _adding = false;
                              _nameCtl.clear();
                              _textCtl.clear();
                            });
                          },
                          style: _cancelStyle,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addTemplate,
                          style: _saveStyle,
                          child: const Text('Save'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],

            // Footer
            if (!_adding) ...[
              const Divider(color: AppColors.border700, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _adding = true);
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _nameFocus.requestFocus());
                  },
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Template'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent400,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

  Widget _field({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      style: AppTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.meta,
        filled: true,
        fillColor: AppColors.bg800,
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

  static final _cancelStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.text400,
    side: const BorderSide(color: AppColors.border700),
    padding: const EdgeInsets.symmetric(vertical: 10),
  );

  static final _saveStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.accent400,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(vertical: 10),
  );
}

class _TemplateRow extends StatefulWidget {
  final String name;
  final String text;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  const _TemplateRow({
    required this.name,
    required this.text,
    required this.onSend,
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
        duration: AppSpacing.fastTransition,
        color: _hovered ? AppColors.bg800 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: AppTypography.body
                        .copyWith(color: AppColors.text100)),
                const SizedBox(height: 2),
                Text(
                  widget.text,
                  style: AppTypography.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            opacity: _hovered ? 1.0 : 0.0,
            duration: AppSpacing.fastTransition,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: widget.onDelete,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 15, color: AppColors.text500),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ]),
          ),
          GestureDetector(
            onTap: widget.onSend,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hovered ? AppColors.accent400 : AppColors.bg800,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _hovered
                        ? AppColors.accent400
                        : AppColors.border700,
                  ),
                ),
                child: Text(
                  'Send',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? Colors.black : AppColors.text400,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
