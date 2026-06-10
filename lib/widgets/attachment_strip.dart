import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/attachment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Horizontal strip of pending attachments shown under the terminal.
/// Click a thumbnail to preview full size; paths are auto-sent with the
/// next Enter, or immediately via the Insert button.
class AttachmentStrip extends StatelessWidget {
  final List<String> attachments;
  final bool running;
  final void Function(String path) onPreview;
  final void Function(int index) onRemove;
  final VoidCallback onClear;
  final VoidCallback onInsert;

  const AttachmentStrip({
    super.key,
    required this.attachments,
    required this.running,
    required this.onPreview,
    required this.onRemove,
    required this.onClear,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(
          color: AppColors.border700,
          width: AppSpacing.cardBorderWidth,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Tooltip(
            message:
                'Attachments are sent with your next Enter (${attachments.length})',
            child: const Icon(Icons.attachment,
                size: 16, color: AppColors.text500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) => AttachmentThumb(
                  path: attachments[index],
                  onTap: () => onPreview(attachments[index]),
                  onRemove: () => onRemove(index),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: running
                ? AppLocalizations.of(context)!.insertPathsTooltip
                : AppLocalizations.of(context)!.terminalNotRunning,
            child: TextButton.icon(
              onPressed: running ? onInsert : null,
              icon: const Icon(Icons.send, size: 14),
              label: Text(AppLocalizations.of(context)!.insert),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent400,
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          Tooltip(
            message: AppLocalizations.of(context)!.clearAllAttachments,
            child: GestureDetector(
              onTap: onClear,
              child: const MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      size: 16, color: AppColors.text500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One 48×48 thumbnail. Images render via [Image.file] (downscaled decode
/// through `cacheWidth` keeps memory flat); failures surface the actual
/// error in a tooltip instead of a silent generic icon.
class AttachmentThumb extends StatefulWidget {
  final String path;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const AttachmentThumb({
    super.key,
    required this.path,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<AttachmentThumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isImage = AttachmentService.isImagePath(widget.path);
    final name = widget.path.split('/').last;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: name,
          waitDuration: const Duration(milliseconds: 400),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.bg900,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        _hovered ? AppColors.accent400 : AppColors.border700,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: isImage
                    ? Image.file(
                        File(widget.path),
                        fit: BoxFit.cover,
                        // Decode at 2x thumb size — fast and memory-flat
                        // even for huge screenshots.
                        cacheWidth: 96,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) => Tooltip(
                          message: AppLocalizations.of(context)!
                              .previewFailed('$error'),
                          child: const Icon(Icons.broken_image_outlined,
                              size: 20, color: AppColors.red400),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.insert_drive_file_outlined,
                              size: 18, color: AppColors.text400),
                          const SizedBox(height: 2),
                          Text(
                            name.contains('.')
                                ? name.split('.').last.toUpperCase()
                                : 'FILE',
                            style: const TextStyle(
                                fontSize: 8, color: AppColors.text500),
                          ),
                        ],
                      ),
              ),
              // Remove badge (always visible, brighter on hover)
              Positioned(
                top: -5,
                right: -5,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _hovered ? AppColors.red400 : AppColors.bg800,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border700),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 10,
                      color: _hovered ? AppColors.bg950 : AppColors.text400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-size preview dialog for an attachment path. Image failures show the
/// underlying error message so problems are diagnosable, never a bare icon.
void showAttachmentPreview(BuildContext context, String path) {
  final isImage = AttachmentService.isImagePath(path);
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(
                    isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 16,
                    color: AppColors.text400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label
                          .copyWith(color: AppColors.text200),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close,
                            size: 16, color: AppColors.text400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: isImage
                  ? InteractiveViewer(
                      maxScale: 6,
                      child: Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_outlined,
                                  size: 48, color: AppColors.red400),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context)!
                                    .previewFailed('$error'),
                                style: AppTypography.bodySmall
                                    .copyWith(color: AppColors.red400),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(48),
                      child: Icon(Icons.insert_drive_file_outlined,
                          size: 64, color: AppColors.text500),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SelectableText(path, style: AppTypography.meta),
            ),
          ],
        ),
      ),
    ),
  );
}
