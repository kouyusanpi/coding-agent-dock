import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../services/settings_service.dart';
import '../services/event_log_service.dart';
import 'cluster_api_dialog.dart';
import 'event_log_panel.dart';
import 'keyboard_shortcuts_dialog.dart';
import 'pipeline_rules_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Right-side settings drawer: font size, notifications, Claude CLI path.
class SettingsDrawer extends StatefulWidget {
  /// Called when terminal font size changes so TerminalPane rebuilds.
  final ValueChanged<double> onFontSizeChanged;

  /// IPC server port — shown as an info row so users can configure hooks.
  final int? ipcPort;

  /// All detected/known agents — passed through to Pipeline Rules dialog.
  final List<AgentCli> agents;

  /// Event log service — passed to EventLogPanel on tap.
  final EventLogService? eventLogService;

  const SettingsDrawer({
    super.key,
    required this.onFontSizeChanged,
    this.ipcPort,
    this.agents = const [],
    this.eventLogService,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  late double _fontSize;
  late bool _notifications;
  late bool _watchdogEnabled;
  late int _watchdogMaxRetries;
  late final TextEditingController _cliPathCtl;

  @override
  void initState() {
    super.initState();
    _fontSize = SettingsService.terminalFontSize;
    _notifications = SettingsService.notificationsEnabled;
    _watchdogEnabled = SettingsService.watchdogEnabled;
    _watchdogMaxRetries = SettingsService.watchdogMaxRetries;
    _cliPathCtl =
        TextEditingController(text: SettingsService.claudeCliPath ?? '');
  }

  @override
  void dispose() {
    _cliPathCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      width: 300,
      backgroundColor: AppColors.bg900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        side: BorderSide(color: AppColors.border700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(children: [
              Expanded(
                  child: Text(l10n.settings,
                      style: AppTypography.cardTitle)),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.text400,
              ),
            ]),
          ),
          const Divider(color: AppColors.border700, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // --- Terminal Font Size ---
                _section(l10n.sectionTerminal),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.fontSize, style: AppTypography.body),
                    Text('${_fontSize.toInt()}px',
                        style: AppTypography.mono
                            .copyWith(color: AppColors.accent400)),
                  ],
                ),
                Slider(
                  value: _fontSize,
                  min: 10,
                  max: 22,
                  divisions: 12,
                  activeColor: AppColors.accent400,
                  onChanged: (v) {
                    setState(() => _fontSize = v);
                    SettingsService.setTerminalFontSize(v);
                    widget.onFontSizeChanged(v);
                  },
                ),

                const SizedBox(height: 20),
                const Divider(color: AppColors.border700, height: 1),
                const SizedBox(height: 20),

                // --- Notifications ---
                _section(l10n.sectionNotifications),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.taskCompletionAlerts,
                            style: AppTypography.body),
                        Text(
                            l10n.taskCompletionAlertsDesc,
                            style: AppTypography.meta),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notifications,
                    activeThumbColor: AppColors.accent400, activeTrackColor: AppColors.accent400,
                    onChanged: (v) {
                      setState(() => _notifications = v);
                      SettingsService.setNotificationsEnabled(v);
                    },
                  ),
                ]),

                const SizedBox(height: 20),
                const Divider(color: AppColors.border700, height: 1),
                const SizedBox(height: 20),

                // --- Watchdog ---
                _section('Watchdog'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-retry on failure',
                            style: AppTypography.body),
                        Text(
                          'Re-launch failed sessions automatically',
                          style: AppTypography.meta,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _watchdogEnabled,
                    activeThumbColor: AppColors.accent400,
                    activeTrackColor: AppColors.accent400,
                    onChanged: (v) {
                      setState(() => _watchdogEnabled = v);
                      SettingsService.setWatchdogEnabled(v);
                    },
                  ),
                ]),
                if (_watchdogEnabled) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Max retries', style: AppTypography.body),
                      Row(
                        children: [
                          _stepBtn(Icons.remove,
                              _watchdogMaxRetries > 1,
                              () {
                            final v = _watchdogMaxRetries - 1;
                            setState(() => _watchdogMaxRetries = v);
                            SettingsService.setWatchdogMaxRetries(v);
                          }),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$_watchdogMaxRetries',
                              style: AppTypography.mono.copyWith(
                                  color: AppColors.accent400),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          _stepBtn(Icons.add,
                              _watchdogMaxRetries < 5,
                              () {
                            final v = _watchdogMaxRetries + 1;
                            setState(() => _watchdogMaxRetries = v);
                            SettingsService.setWatchdogMaxRetries(v);
                          }),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only retries sessions that ran ≥5 s (skips instant crashes).',
                    style: AppTypography.meta,
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(color: AppColors.border700, height: 1),
                const SizedBox(height: 20),

                // --- Claude CLI path ---
                _section('Claude Code CLI'),
                const SizedBox(height: 8),
                Text(l10n.binaryPathOverride,
                    style: AppTypography.body),
                const SizedBox(height: 4),
                Text(
                    l10n.binaryPathDesc,
                    style: AppTypography.meta),
                const SizedBox(height: 8),
                TextField(
                  controller: _cliPathCtl,
                  style: AppTypography.mono.copyWith(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '/Users/you/.local/bin/claude',
                    hintStyle: AppTypography.meta,
                    filled: true,
                    fillColor: AppColors.bg800,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(
                          color: AppColors.border800),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(
                          color: AppColors.border800),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(
                          color: AppColors.accent400),
                    ),
                  ),
                  onChanged: (v) =>
                      SettingsService.setClaudeCliPath(v),
                ),

                const SizedBox(height: 20),
                const Divider(color: AppColors.border700, height: 1),
                const SizedBox(height: 20),

                // --- IPC Server ---
                _section('IPC Server'),
                const SizedBox(height: 8),
                _IpcInfoRow(ipcPort: widget.ipcPort),

                const SizedBox(height: 20),
                const Divider(color: AppColors.border700, height: 1),
                const SizedBox(height: 12),

                // --- Pipeline Rules ---
                GestureDetector(
                  onTap: () => PipelineRulesDialog.show(
                    context,
                    agents: widget.agents,
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(children: [
                      const Icon(Icons.account_tree_outlined,
                          size: 14, color: AppColors.text500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Pipeline Rules',
                            style: AppTypography.body.copyWith(
                                color: AppColors.text400)),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.text500),
                    ]),
                  ),
                ),

                const SizedBox(height: 10),

                // --- Cluster API reference ---
                GestureDetector(
                  onTap: () => ClusterApiDialog.show(context),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(children: [
                      const Icon(Icons.hub_outlined,
                          size: 14, color: AppColors.text500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Cluster API',
                            style: AppTypography.body.copyWith(
                                color: AppColors.text400)),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.text500),
                    ]),
                  ),
                ),

                const SizedBox(height: 10),

                // --- Event Log ---
                if (widget.eventLogService != null)
                  GestureDetector(
                    onTap: () => EventLogPanel.show(
                      context,
                      logService: widget.eventLogService!,
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(children: [
                        const Icon(Icons.timeline_outlined,
                            size: 14, color: AppColors.text500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Event Log',
                              style: AppTypography.body.copyWith(
                                  color: AppColors.text400)),
                        ),
                        const Text('⇧⌘L', style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          color: AppColors.text500,
                        )),
                      ]),
                    ),
                  ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.border700, height: 1),
                const SizedBox(height: 12),

                // --- Keyboard shortcuts ---
                GestureDetector(
                  onTap: () => KeyboardShortcutsDialog.show(context),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(children: [
                      const Icon(Icons.keyboard_outlined,
                          size: 14, color: AppColors.text500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.keyboardShortcuts,
                            style: AppTypography.body.copyWith(
                                color: AppColors.text400)),
                      ),
                      const Text('⌘/', style: TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 11,
                        color: AppColors.text500,
                      )),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Text(
        title.toUpperCase(),
        style: AppTypography.sectionHeader,
      );

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.accent400 : AppColors.text500,
        ),
      ),
    );
  }
}

/// Shows the local IPC server status + the env var names to use in hooks.
class _IpcInfoRow extends StatelessWidget {
  final int? ipcPort;
  const _IpcInfoRow({this.ipcPort});

  @override
  Widget build(BuildContext context) {
    if (ipcPort == null) {
      return Row(children: [
        const Icon(Icons.circle, size: 7, color: AppColors.text500),
        const SizedBox(width: 6),
        Text('Not running', style: AppTypography.meta),
      ]);
    }

    final url = 'http://127.0.0.1:$ipcPort';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.circle, size: 7, color: AppColors.emerald500),
          const SizedBox(width: 6),
          Text('Listening on port $ipcPort',
              style: AppTypography.meta.copyWith(color: AppColors.text200)),
        ]),
        const SizedBox(height: 8),
        Text(
          'Agent CLIs can POST events via the AGENTDOCK_IPC_URL env var '
          'automatically injected into every session. '
          'Add to Claude Code hooks (~/.claude/settings.json):',
          style: AppTypography.meta,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            final snippet = _hookSnippet(ipcPort!);
            Clipboard.setData(ClipboardData(text: snippet));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hook snippet copied'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg800,
                borderRadius:
                    BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(color: AppColors.border700),
              ),
              child: Text(
                '"Stop": [{"type":"command","command":\n'
                '  "curl -sf -X POST \$AGENTDOCK_IPC_URL \\\n'
                '    -H \'Content-Type: application/json\' \\\n'
                '    -d \'{\\"type\\":\\"stop\\"}\' || true"}]',
                style: AppTypography.mono.copyWith(
                  fontSize: 10,
                  color: AppColors.text400,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('Tap to copy · URL: $url',
            style: AppTypography.meta.copyWith(fontSize: 10)),
      ],
    );
  }

  static String _hookSnippet(int port) => '''
"hooks": {
  "Stop": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "curl -sf -X POST \$AGENTDOCK_IPC_URL -H 'Content-Type: application/json' -d '{\\"type\\":\\"stop\\"}' || true"
    }]
  }]
}''';
}
