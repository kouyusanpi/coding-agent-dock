import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Reference dialog showing how to use the local Cluster REST API
/// from Claude Code hooks and shell scripts.
class ClusterApiDialog extends StatelessWidget {
  const ClusterApiDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => const ClusterApiDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border700),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                const Icon(Icons.hub_outlined,
                    size: 18, color: AppColors.accent400),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cluster API', style: AppTypography.cardTitle),
                      SizedBox(height: 2),
                      Text(
                        'Connect agents via the local REST API',
                        style: TextStyle(fontSize: 12, color: AppColors.text500),
                      ),
                    ],
                  ),
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

            // --- Content ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shell helpers
                    _SectionHeader(
                        icon: Icons.terminal_outlined,
                        label: 'Shell helpers (quickest path)'),
                    const SizedBox(height: 8),
                    _Snippet(
                      label: 'Source the helpers file in any hook or script',
                      code: 'source "\$AGENTDOCK_HELPERS"\n\n'
                          '# Then use the built-in functions:\n'
                          'agentdock_list              # list all sessions\n'
                          'agentdock_output 42 20      # last 20 lines of session 42\n'
                          'agentdock_inject 42 "hello" # write to session 42\n'
                          'agentdock_stream 42         # live output stream\n'
                          'agentdock_broadcast "sync"  # message all other agents\n'
                          'agentdock_notify stop       # signal this session done',
                    ),

                    const SizedBox(height: 20),
                    // Env vars
                    _SectionHeader(
                        icon: Icons.settings_ethernet_outlined,
                        label: 'Environment variables (auto-injected)'),
                    const SizedBox(height: 8),
                    _CodeBlock(
                      code: 'AGENTDOCK_API_BASE    \$AGENTDOCK_API_BASE\n'
                          'AGENTDOCK_HELPERS     \$AGENTDOCK_HELPERS\n'
                          'AGENTDOCK_SESSION_ID  \$AGENTDOCK_SESSION_ID\n'
                          'AGENTDOCK_IPC_URL     \$AGENTDOCK_IPC_URL',
                      copyable: false,
                    ),

                    const SizedBox(height: 20),
                    _SectionHeader(
                        icon: Icons.code_outlined, label: 'Raw curl reference'),
                    const SizedBox(height: 10),

                    _Snippet(
                      label: 'List all running agents',
                      code:
                          'curl "\$AGENTDOCK_API_BASE/sessions"',
                    ),
                    const SizedBox(height: 8),
                    _Snippet(
                      label: 'Read another agent\'s output',
                      code:
                          'curl "\$AGENTDOCK_API_BASE/sessions/<id>/output?maxLines=20"',
                    ),
                    const SizedBox(height: 8),
                    _Snippet(
                      label: 'Inject text into another agent',
                      code: 'curl -X POST "\$AGENTDOCK_API_BASE/sessions/<id>/inject" \\\n'
                          '  -H "Content-Type: application/json" \\\n'
                          '  -d \'{"text": "please summarize what you found"}\'',
                    ),
                    const SizedBox(height: 8),
                    _Snippet(
                      label: 'Post a stop event (Claude Code hook)',
                      code: 'curl -sf -X POST "\$AGENTDOCK_IPC_URL" \\\n'
                          '  -H "Content-Type: application/json" \\\n'
                          '  -d \'{"type":"stop"}\' || true',
                    ),

                    const SizedBox(height: 20),
                    _SectionHeader(
                        icon: Icons.integration_instructions_outlined,
                        label: 'Claude Code hook example'),
                    const SizedBox(height: 8),
                    _CodeBlock(
                      code: '// ~/.claude/settings.json\n'
                          '"hooks": {\n'
                          '  "Stop": [{\n'
                          '    "matcher": "",\n'
                          '    "hooks": [{\n'
                          '      "type": "command",\n'
                          '      "command": "curl -sf -X POST \$AGENTDOCK_IPC_URL"\n'
                          '        " -H \'Content-Type: application/json\'"\n'
                          '        " -d \'{\\"type\\":\\"stop\\"}\' || true"\n'
                          '    }]\n'
                          '  }]\n'
                          '}',
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent400.withAlpha(15),
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(
                            color: AppColors.accent400.withAlpha(40)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.accent400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The port changes each launch. Always use the env vars — '
                            'never hardcode the port number.',
                            style: AppTypography.meta
                                .copyWith(color: AppColors.text400),
                          ),
                        ),
                      ]),
                    ),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: AppColors.accent400),
      const SizedBox(width: 6),
      Text(
        label.toUpperCase(),
        style: AppTypography.sectionHeader,
      ),
    ]);
  }
}

class _Snippet extends StatefulWidget {
  final String label;
  final String code;

  const _Snippet({required this.label, required this.code});

  @override
  State<_Snippet> createState() => _SnippetState();
}

class _SnippetState extends State<_Snippet> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: AppTypography.meta.copyWith(color: AppColors.text400)),
        const SizedBox(height: 4),
        _CodeBlock(code: widget.code, onCopy: _copy, copied: _copied),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  final VoidCallback? onCopy;
  final bool copied;
  final bool copyable;

  const _CodeBlock({
    required this.code,
    this.onCopy,
    this.copied = false,
    this.copyable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.border700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              code,
              style: AppTypography.mono.copyWith(
                fontSize: 11,
                color: AppColors.text200,
                height: 1.5,
              ),
            ),
          ),
          if (copyable && onCopy != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: copied ? 'Copied!' : 'Copy',
              child: InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    copied ? Icons.check : Icons.copy_outlined,
                    size: 13,
                    color: copied ? AppColors.emerald500 : AppColors.text500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
