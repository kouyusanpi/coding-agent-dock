import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../models/session_template.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A command-palette entry: either a session or a quick action.
sealed class _PaletteEntry {
  String get title;
  String get subtitle;
  IconData get icon;
}

final class _SessionEntry extends _PaletteEntry {
  final TaskSession session;
  final String agentName;
  _SessionEntry(this.session, this.agentName);

  @override
  String get title => session.name;
  @override
  String get subtitle => agentName;
  @override
  IconData get icon => Icons.terminal;
}

final class _ActionEntry extends _PaletteEntry {
  @override
  final String title;
  @override
  final String subtitle;
  @override
  final IconData icon;
  final VoidCallback action;

  _ActionEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
  });
}

final class _TemplateEntry extends _PaletteEntry {
  final SessionTemplate template;
  final String agentName;

  _TemplateEntry(this.template, this.agentName);

  @override
  String get title => template.name;
  @override
  String get subtitle => agentName;
  @override
  IconData get icon => Icons.bookmark_outline;
}

/// Modal command palette overlay — Cmd+K to open, Esc/click-outside to close.
///
/// Shows a filtered list of open sessions + quick actions. ↑↓ navigates,
/// Enter executes the focused item.
class CommandPalette extends StatefulWidget {
  final List<TaskSession> sessions;
  final List<AgentCli> agents;
  final void Function(TaskSession) onOpenSession;
  final VoidCallback onNewTask;
  final VoidCallback onRescan;
  final VoidCallback onOpenSettings;

  /// Opens NewSessionDialog with ALL detected agents — "benchmark on all" flow.
  /// Shown only when ≥2 agents are detected.
  final VoidCallback? onRunOnAllAgents;

  /// Opens the broadcast dialog — shown only when [runningAgentCount] ≥ 1.
  final VoidCallback? onBroadcast;

  /// Number of currently running agent terminals (drives broadcast visibility).
  final int runningAgentCount;

  /// Saved session templates — shown as quick-launch entries.
  final List<SessionTemplate> templates;

  /// Called when the user selects a template to launch.
  final void Function(SessionTemplate)? onLaunchTemplate;

  /// Opens the template manager dialog.
  final VoidCallback? onManageTemplates;

  /// Opens the pipeline rules dialog.
  final VoidCallback? onManagePipelineRules;

  /// Opens the live agent dashboard.
  final VoidCallback? onOpenDashboard;

  /// Opens the cluster event log.
  final VoidCallback? onOpenEventLog;

  /// Opens the workflow templates dialog.
  final VoidCallback? onOpenWorkflows;

  /// Opens the skill manager dialog.
  final VoidCallback? onOpenSkills;

  const CommandPalette({
    super.key,
    required this.sessions,
    required this.agents,
    required this.onOpenSession,
    required this.onNewTask,
    required this.onRescan,
    required this.onOpenSettings,
    this.onRunOnAllAgents,
    this.onBroadcast,
    this.runningAgentCount = 0,
    this.templates = const [],
    this.onLaunchTemplate,
    this.onManageTemplates,
    this.onManagePipelineRules,
    this.onOpenDashboard,
    this.onOpenEventLog,
    this.onOpenWorkflows,
    this.onOpenSkills,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  int _selected = 0;

  List<_PaletteEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _query.addListener(_rebuild);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _inputFocus.requestFocus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildEntries();
  }

  @override
  void dispose() {
    _query.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  String _agentName(String cliId) =>
      widget.agents
          .firstWhere((a) => a.id == cliId,
              orElse: () => AgentCli(
                  id: cliId,
                  displayName: cliId,
                  binaryName: cliId,
                  lastChecked: DateTime.now()))
          .displayName;

  void _rebuild() {
    _buildEntries();
    setState(() => _selected = 0);
  }

  void _buildEntries() {
    final q = _query.text.trim().toLowerCase();
    final l10n = AppLocalizations.of(context)!;

    final detectedCount = widget.agents.where((a) => a.detected).length;

    final actions = <_ActionEntry>[
      _ActionEntry(
        title: l10n.newTask,
        subtitle: l10n.newTaskSubtitle,
        icon: Icons.add_circle_outline,
        action: () {
          Navigator.of(context).pop();
          widget.onNewTask();
        },
      ),
      if (widget.onRunOnAllAgents != null && detectedCount >= 2)
        _ActionEntry(
          title: l10n.runOnAllAgents,
          subtitle: l10n.runOnAllAgentsSubtitle(detectedCount),
          icon: Icons.hub_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onRunOnAllAgents!();
          },
        ),
      if (widget.onBroadcast != null && widget.runningAgentCount >= 1)
        _ActionEntry(
          title: l10n.broadcastTitle(widget.runningAgentCount),
          subtitle: l10n.commandBroadcastSubtitle(widget.runningAgentCount),
          icon: Icons.wifi_tethering,
          action: () {
            Navigator.of(context).pop();
            widget.onBroadcast!();
          },
        ),
      _ActionEntry(
        title: l10n.rescanAgents,
        subtitle: l10n.rescanAgentsSubtitle,
        icon: Icons.refresh,
        action: () {
          Navigator.of(context).pop();
          widget.onRescan();
        },
      ),
      _ActionEntry(
        title: l10n.openSettings,
        subtitle: l10n.openSettingsSubtitle,
        icon: Icons.settings_outlined,
        action: () {
          Navigator.of(context).pop();
          widget.onOpenSettings();
        },
      ),
      if (widget.onManageTemplates != null && widget.templates.isNotEmpty)
        _ActionEntry(
          title: 'Manage templates',
          subtitle: '${widget.templates.length} saved template${widget.templates.length == 1 ? '' : 's'}',
          icon: Icons.bookmark_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onManageTemplates!();
          },
        ),
      if (widget.onManagePipelineRules != null)
        _ActionEntry(
          title: 'Pipeline Rules',
          subtitle: 'Manage auto-relay rules between agents',
          icon: Icons.account_tree_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onManagePipelineRules!();
          },
        ),
      if (widget.onOpenDashboard != null)
        _ActionEntry(
          title: 'Live Dashboard',
          subtitle: 'View all agents and live output (⇧⌘D)',
          icon: Icons.grid_view_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onOpenDashboard!();
          },
        ),
      if (widget.onOpenEventLog != null)
        _ActionEntry(
          title: 'Event Log',
          subtitle: 'Timeline of cluster events — starts, completions, relays (⇧⌘L)',
          icon: Icons.timeline_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onOpenEventLog!();
          },
        ),
      if (widget.onOpenWorkflows != null)
        _ActionEntry(
          title: 'Workflows',
          subtitle: 'Manage and launch DAG workflow templates (⇧⌘W)',
          icon: Icons.account_tree_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onOpenWorkflows!();
          },
        ),
      if (widget.onOpenSkills != null)
        _ActionEntry(
          title: 'Skills',
          subtitle: 'Manage and create Claude skill files (⇧⌘K)',
          icon: Icons.auto_awesome_outlined,
          action: () {
            Navigator.of(context).pop();
            widget.onOpenSkills!();
          },
        ),
    ];

    // "@claude ..." prefix filters sessions to the named agent.
    String? agentFilter;
    String effectiveQ = q;
    if (q.startsWith('@')) {
      final parts = q.substring(1).split(' ');
      agentFilter = parts.first.toLowerCase();
      effectiveQ = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    bool matchesQuery(String text) =>
        effectiveQ.isEmpty || text.toLowerCase().contains(effectiveQ);

    bool matchesAgentFilter(String cliId) {
      final af = agentFilter;
      if (af == null || af.isEmpty) return true;
      return _agentName(cliId).toLowerCase().contains(af);
    }

    final sessions = widget.sessions
        .where((s) =>
            matchesAgentFilter(s.agentCliId) &&
            (matchesQuery(s.name) || matchesQuery(s.input ?? '')))
        .map((s) => _SessionEntry(s, _agentName(s.agentCliId)))
        .toList();

    // Actions are hidden when using @agent filter (session-focused query).
    final filteredActions = agentFilter != null
        ? <_ActionEntry>[]
        : actions.where((a) => matchesQuery(a.title)).toList();

    final templateEntries = widget.templates
        .where((t) =>
            matchesAgentFilter(t.agentId) &&
            (matchesQuery(t.name) ||
                matchesQuery(t.prompt) ||
                matchesQuery(_agentName(t.agentId))))
        .map((t) => _TemplateEntry(t, _agentName(t.agentId)))
        .toList();

    _entries = [...templateEntries, ...sessions, ...filteredActions];
  }

  void _execute(int index) {
    if (index < 0 || index >= _entries.length) return;
    final entry = _entries[index];
    if (entry is _TemplateEntry) {
      Navigator.of(context).pop();
      widget.onLaunchTemplate?.call(entry.template);
    } else if (entry is _SessionEntry) {
      Navigator.of(context).pop();
      widget.onOpenSession(entry.session);
    } else if (entry is _ActionEntry) {
      entry.action();
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() =>
            _selected = (_selected + 1).clamp(0, _entries.length - 1));
        return true;
      case LogicalKeyboardKey.arrowUp:
        setState(() =>
            _selected = (_selected - 1).clamp(0, _entries.length - 1));
        return true;
      case LogicalKeyboardKey.enter:
        _execute(_selected);
        return true;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent dismiss when tapping inside
              child: Container(
                width: 560,
                constraints:
                    const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                  color: AppColors.bg900,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border700),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                // CommandPalette is shown via showDialog without a Dialog/
                // Scaffold wrapper, so it must supply its own Material ancestor
                // for the TextField and ink effects.
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Search input ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              size: 18, color: AppColors.text500),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _query,
                              focusNode: _inputFocus,
                              style: AppTypography.body
                                  .copyWith(color: AppColors.text100),
                              cursorColor: AppColors.accent400,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!
                                    .paletteSearchHint,
                                hintStyle: const TextStyle(
                                    color: AppColors.text500, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg800,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Esc',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.text500)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 16, color: AppColors.border700),

                    // --- Results list ---
                    if (_entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(AppLocalizations.of(context)!.noResults,
                            style: AppTypography.bodySmall),
                      )
                    else
                      // Hard-cap the scroll region so a long result set can't
                      // overflow the 480px dialog. shrinkWrap keeps the palette
                      // short for a few results; beyond the cap it scrolls.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding:
                              const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: _entries.length,
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final selected = i == _selected;
                            return GestureDetector(
                              onTap: () => _execute(i),
                              onTapDown: (_) =>
                                  setState(() => _selected = i),
                              child: MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _selected = i),
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.accent10
                                        : Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: selected
                                        ? Border.all(
                                            color: AppColors.accent400
                                                .withAlpha(80))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        e.icon,
                                        size: 16,
                                        color: selected
                                            ? AppColors.accent400
                                            : (e is _TemplateEntry
                                                ? AppColors.labelYellow
                                                : AppColors.text500),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.title,
                                              style: AppTypography.body
                                                  .copyWith(
                                                color: selected
                                                    ? AppColors.text100
                                                    : AppColors.text200,
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              e.subtitle,
                                              style: AppTypography.meta,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            if (e is _TemplateEntry &&
                                                e.template.prompt
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                e.template.prompt,
                                                style: AppTypography.mono
                                                    .copyWith(
                                                  fontSize: 10,
                                                  color: AppColors.text500,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (selected)
                                        const Text('↵',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.text500)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
