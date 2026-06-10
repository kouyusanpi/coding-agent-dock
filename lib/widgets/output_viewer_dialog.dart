import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Full output viewer — shows the stored terminal output for a completed
/// session in a scrollable, copyable modal.
class OutputViewerDialog extends StatelessWidget {
  final String sessionName;
  final String output;

  const OutputViewerDialog({
    super.key,
    required this.sessionName,
    required this.output,
  });

  static Future<void> show(
    BuildContext context, {
    required String sessionName,
    required String output,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => OutputViewerDialog(
        sessionName: sessionName,
        output: output,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(children: [
                const Icon(Icons.terminal,
                    size: 16, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.viewFullOutput,
                          style: AppTypography.cardTitle),
                      Text(sessionName,
                          style: AppTypography.meta,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Copy button
                Tooltip(
                  message: l10n.copyOutput,
                  child: IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: output));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l10n.copyOutput),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.bg800,
                        ));
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    color: AppColors.text400,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.text400,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            const Divider(color: AppColors.border700, height: 1),

            // --- Scrollable output ---
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    output,
                    style: AppTypography.mono.copyWith(
                      fontSize: 12,
                      color: AppColors.text200,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
