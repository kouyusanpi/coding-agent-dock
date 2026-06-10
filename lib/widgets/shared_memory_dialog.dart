import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../services/project_memory_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Editor for a project's shared memory file
/// (`<project>/.agentdock/shared-memory.md`).
///
/// Saving propagates the content into every agent's native memory file in the
/// project, so all code agents working in the same directory share context.
class SharedMemoryDialog extends StatefulWidget {
  final String projectPath;

  /// Skip async load and pre-populate the editor. Tests only.
  @visibleForTesting
  final String? initialContent;

  /// Override the save operation. Tests only — avoids dart:io in fakeAsync.
  @visibleForTesting
  final Future<void> Function(String content)? onSave;

  const SharedMemoryDialog({super.key, required this.projectPath})
      : initialContent = null,
        onSave = null;

  @visibleForTesting
  const SharedMemoryDialog.withContent({
    super.key,
    required this.projectPath,
    required String content,
    this.onSave,
  }) : initialContent = content;

  static Future<void> show(BuildContext context, String projectPath) {
    return showDialog<void>(
      context: context,
      builder: (_) => SharedMemoryDialog(projectPath: projectPath),
    );
  }

  @override
  State<SharedMemoryDialog> createState() => _SharedMemoryDialogState();
}

class _SharedMemoryDialogState extends State<SharedMemoryDialog> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _controller.text = widget.initialContent!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final content = await ProjectMemoryService.readShared(widget.projectPath);
    if (!mounted) return;
    setState(() {
      _controller.text = content;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    if (widget.onSave != null) {
      await widget.onSave!(_controller.text);
    } else {
      await ProjectMemoryService.writeShared(widget.projectPath, _controller.text);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.psychology_outlined,
                size: 16, color: AppColors.accent400),
            const SizedBox(width: 8),
            Text(l10n.sharedMemoryTitle, style: AppTypography.cardTitle),
          ]),
          const SizedBox(height: 4),
          Text(
            p.basename(widget.projectPath),
            style: AppTypography.meta.copyWith(color: AppColors.text500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sharedMemoryDescription,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.text400),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 8,
                    maxLines: 14,
                    style: AppTypography.body.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.text200,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.sharedMemoryPlaceholder,
                      hintStyle: AppTypography.bodySmall
                          .copyWith(color: AppColors.text500),
                      filled: true,
                      fillColor: AppColors.bg800,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_saving || _loading) ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
