import 'package:flutter/material.dart';

import '../models/agent_cli.dart';

/// Displays the list of detected/undetected agent CLIs.
class CliListScreen extends StatelessWidget {
  final List<AgentCli> clis;
  final bool isDetecting;

  const CliListScreen({
    super.key,
    required this.clis,
    this.isDetecting = false,
  });

  @override
  Widget build(BuildContext context) {
    if (clis.isEmpty) {
      return const Center(child: Text('No CLIs registered.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: clis.length,
      itemBuilder: (context, index) => _CliCard(cli: clis[index]),
    );
  }
}

/// Individual CLI status card.
class _CliCard extends StatelessWidget {
  final AgentCli cli;

  const _CliCard({required this.cli});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine the status color and icon
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (cli.detected && cli.version != null) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = 'Installed';
    } else if (cli.detected) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
      statusLabel = 'Found (version unknown)';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.cancel;
      statusLabel = 'Not found';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name + status
            Row(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cli.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Row 2: Binary + version
            Row(
              children: [
                // Binary info
                Icon(
                  Icons.terminal,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  cli.binaryName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                if (cli.version != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.tag,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cli.version!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),

            // Path (if detected)
            if (cli.binaryPath != null) ...[
              const SizedBox(height: 4),
              Text(
                cli.binaryPath!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],

            // Error (if any)
            if (cli.error != null && cli.error!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cli.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],

            // Last checked timestamp
            const SizedBox(height: 4),
            Text(
              'Checked: ${_formatDateTime(cli.lastChecked)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
