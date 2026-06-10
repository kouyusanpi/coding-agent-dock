import 'package:flutter/material.dart';

import '../services/event_log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Compact timeline feed of recent cluster events.
///
/// Shown as a dialog accessible from Settings → Event Log or ⇧⌘L.
class EventLogPanel extends StatefulWidget {
  final EventLogService logService;

  const EventLogPanel({super.key, required this.logService});

  static Future<void> show(
    BuildContext context, {
    required EventLogService logService,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => EventLogPanel(logService: logService),
    );
  }

  @override
  State<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<EventLogPanel> {
  @override
  void initState() {
    super.initState();
    widget.logService.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.logService.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final events = widget.logService.recent(count: 100);

    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.timeline_outlined,
                    size: 18, color: AppColors.accent400),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Event Log', style: AppTypography.cardTitle),
                ),
                if (events.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      widget.logService.clear();
                    },
                    child: const Text('Clear',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.text500)),
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

            // --- Body ---
            Flexible(
              child: events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timeline_outlined,
                              size: 36, color: AppColors.text500),
                          const SizedBox(height: 12),
                          Text('No events yet',
                              style: AppTypography.body
                                  .copyWith(color: AppColors.text400)),
                          const SizedBox(height: 6),
                          Text(
                            'Events appear here as sessions run,\n'
                            'pipeline rules fire, and agents signal.',
                            style: AppTypography.meta,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: events.length,
                      itemBuilder: (_, i) => _EventRow(event: events[i]),
                    ),
            ),

            // --- Footer ---
            if (events.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Text(
                  '${widget.logService.count} total · showing last ${events.length}',
                  style: AppTypography.meta.copyWith(
                      color: AppColors.text500, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final ClusterEvent event;

  const _EventRow({required this.event});

  Color get _dotColor {
    if (event.isError) return AppColors.red400;
    if (event.isSuccess) return AppColors.emerald500;
    return AppColors.accent400;
  }

  String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5, right: 10),
                decoration:
                    BoxDecoration(color: _dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: event.sessionName,
                              style: AppTypography.body.copyWith(
                                color: AppColors.text200,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: event.kindLabel,
                              style: AppTypography.body.copyWith(
                                color: _dotColor,
                              ),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeLabel(event.timestamp),
                      style: AppTypography.meta,
                    ),
                  ],
                ),
                if (event.detail != null && event.detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event.detail!,
                      style: AppTypography.mono.copyWith(
                        fontSize: 10,
                        color: AppColors.text500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
