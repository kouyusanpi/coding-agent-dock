import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Keyboard shortcuts reference dialog.
///
/// Triggered by ⌘/ in [HomeScreen] or via the Settings drawer.
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => const KeyboardShortcutsDialog(),
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.keyboard_outlined,
                    size: 18, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.keyboardShortcuts,
                      style: AppTypography.cardTitle),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.text400,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            const Divider(color: AppColors.border700, height: 1),

            // --- Shortcut rows ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(title: l10n.shortcutsGlobal, rows: [
                      _Row('⌘K', l10n.shortcutCommandPalette),
                      _Row('⌘N', l10n.newTask),
                      _Row('⇧⌘N', l10n.shortcutNewTaskClipboard),
                      _Row('⌘,', l10n.openSettings),
                      _Row('⌘/', l10n.shortcutShowShortcuts),
                    ]),
                    const SizedBox(height: 16),
                    _Section(title: l10n.shortcutsTabs, rows: [
                      _Row('⌘]', l10n.shortcutNextTab),
                      _Row('⌘[', l10n.shortcutPrevTab),
                      _Row('⌘1–9', l10n.shortcutJumpToTab),
                      _Row('⌘W', l10n.shortcutCloseTab),
                    ]),
                    const SizedBox(height: 16),
                    _Section(title: l10n.shortcutsTerminal, rows: [
                      _Row('⌘F', l10n.shortcutSearch),
                      _Row('⌘E', l10n.shortcutExport),
                    ]),
                    const SizedBox(height: 16),
                    _Section(title: l10n.shortcutsAgents, rows: [
                      _Row('⇧⌘B', l10n.shortcutBroadcast),
                      _Row('⇧⌘I', l10n.shortcutInjectActive),
                      _Row('⇧⌘G', 'Pipeline Rules'),
                      _Row('⇧⌘D', 'Live Dashboard'),
                      _Row('⇧⌘L', 'Event Log'),
                      _Row('⇧⌘W', 'Workflows'),
                      _Row('⇧⌘K', 'Skills'),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.sectionHeader,
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String keys;
  final String description;

  const _Row(this.keys, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.bg800,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(color: AppColors.border700),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11,
                color: AppColors.accent400,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: AppTypography.body),
          ),
        ],
      ),
    );
  }
}
