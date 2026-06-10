import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// One-click slash commands shown above the terminal input area.
///
/// Clicking a chip types the command into the running CLI and presses
/// Enter — a fast path for frequent commands like `/context` or `/model`.
class QuickCommandsBar extends StatelessWidget {
  /// Commands frequently used in agent CLI sessions (Claude Code et al.).
  static const List<String> commands = [
    '/context',
    '/model',
    '/cost',
    '/compact',
    '/clear',
    '/resume',
    '/help',
  ];

  /// Sends the command text (with trailing Enter) to the active terminal.
  final ValueChanged<String> onSend;

  const QuickCommandsBar({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: commands.length,
        separatorBuilder: (_, i) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cmd = commands[i];
          return _CommandChip(
            label: cmd,
            onTap: () => onSend('$cmd\r'),
          );
        },
      ),
    );
  }
}

class _CommandChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _CommandChip({required this.label, required this.onTap});

  @override
  State<_CommandChip> createState() => _CommandChipState();
}

class _CommandChipState extends State<_CommandChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppSpacing.fastTransition,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent10 : AppColors.bg800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? AppColors.accent400 : AppColors.border700,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Menlo',
              color: _hovered ? AppColors.accent400 : AppColors.text400,
            ),
          ),
        ),
      ),
    );
  }
}
