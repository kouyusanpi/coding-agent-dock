import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/terminal_sessions_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog that sends a freeform message to one or all running agent terminals.
///
/// When [agentName] is null, sends to all running agents (broadcast mode).
/// When [agentName] is set, shows a single-agent title (inject mode).
class BroadcastDialog extends StatefulWidget {
  final int runningCount;

  /// When non-null, the dialog shows a single-agent title with this name.
  final String? agentName;

  final int Function(String text) onBroadcast;

  const BroadcastDialog({
    super.key,
    required this.runningCount,
    this.agentName,
    required this.onBroadcast,
  });

  static Future<void> show(
      BuildContext context, TerminalSessionsController terminals) {
    return showDialog<void>(
      context: context,
      builder: (_) => BroadcastDialog(
        runningCount: terminals.runningTerminals.length,
        onBroadcast: terminals.broadcast,
      ),
    );
  }

  static Future<void> showForSession(
    BuildContext context,
    TerminalSessionsController terminals,
    int sessionId,
    String sessionName,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => BroadcastDialog(
        runningCount: 1,
        agentName: sessionName,
        onBroadcast: (text) => terminals.sendToSession(sessionId, text),
      ),
    );
  }

  @override
  State<BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<BroadcastDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onBroadcast(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: Row(children: [
        Icon(
          widget.agentName != null ? Icons.send_outlined : Icons.hub_outlined,
          size: 16,
          color: AppColors.emerald500,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.agentName != null
                ? l10n.injectMessageTitle(widget.agentName!)
                : l10n.broadcastTitle(widget.runningCount),
            style: AppTypography.cardTitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.agentName != null
                  ? l10n.injectMessageDescription
                  : l10n.broadcastDescription,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.text400),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              style: AppTypography.body.copyWith(
                fontFamily: 'monospace',
                color: AppColors.text200,
              ),
              decoration: InputDecoration(
                hintText: l10n.broadcastPlaceholder,
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
              onSubmitted: (_) => _send(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _send,
          icon: const Icon(Icons.send, size: 14),
          label: Text(l10n.broadcastSend),
        ),
      ],
    );
  }
}
