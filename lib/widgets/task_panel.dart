import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../services/export_service.dart';
import '../services/terminal_sessions_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/ansi_utils.dart';
import 'broadcast_dialog.dart';
import 'cluster_comparison_dialog.dart';
import 'output_viewer_dialog.dart';
import 'shared_memory_dialog.dart';

/// Format a relative time string (e.g. 'just now', '3 minutes ago').
String _fmtDate(AppLocalizations l10n, DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
  return l10n.daysAgo(diff.inDays);
}

/// Format a duration in milliseconds to a compact human-readable string.
String _formatDurationMs(int? ms) {
  if (ms == null) return '—';
  if (ms < 1000) return '${ms}ms';
  if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  return '${m}m ${s}s';
}

/// Shared status → dot color mapping used by the task panel and the
/// terminal tab strip.
Color statusDotColor(String status) {
  switch (status) {
    case 'running':
      return AppColors.emerald500;
    case 'completed':
      return AppColors.accent400;
    case 'failed':
      return AppColors.red400;
    case 'cancelled':
      return AppColors.text500;
    default: // created
      return AppColors.text400;
  }
}

/// Session count stats — subscribes to its own fork of the stream so it
/// doesn't conflict with the outer StreamBuilder in [TaskPanel].
class _SessionStats extends StatefulWidget {
  final Stream<List<TaskSession>> sessionsStream;
  final int runningCount;
  final AppLocalizations l10n;

  const _SessionStats({
    required this.sessionsStream,
    required this.runningCount,
    required this.l10n,
  });

  @override
  State<_SessionStats> createState() => _SessionStatsState();
}

class _SessionStatsState extends State<_SessionStats> {
  int _total = 0;
  StreamSubscription<List<TaskSession>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.sessionsStream.listen(
      (list) { if (mounted) setState(() => _total = list.length); },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0) return const SizedBox.shrink();
    final stats = widget.runningCount > 0
        ? '$_total · ${widget.l10n.runningCount(widget.runningCount)}'
        : '$_total ${widget.l10n.sessions}';
    return Text(
      stats,
      style: AppTypography.meta.copyWith(
        color: widget.runningCount > 0
            ? AppColors.emerald500
            : AppColors.text500,
      ),
    );
  }
}

/// Sidebar panel listing task sessions with its own search box and a row
/// of agent-type filter chips (shared selection state with the sidebar's
/// agent list — empty set = all agents). The external [searchQuery] from
/// the global search bar is combined with the inline query.
///
/// Each row shows a live status dot (running terminals override the stored
/// DB status), and clicking a row opens/switches the right-hand terminal —
/// the many-tasks × many-agents switchboard.
class TaskPanel extends StatefulWidget {
  /// Key for the clear-finished button (used by widget tests).
  static const Key clearButtonKey = Key('task_panel_clear');
  final Stream<List<TaskSession>> sessionsStream;
  final TerminalSessionsController terminals;
  final String searchQuery;
  final List<AgentCli> agents;
  final Set<String> selectedAgentIds;
  final ValueChanged<String> onToggleAgent;
  final VoidCallback onClearAgents;
  final String Function(String cliId) agentNameOf;
  final void Function(TaskSession session) onOpen;
  final void Function(TaskSession session) onDelete;
  final void Function(TaskSession session, String newName) onRename;
  final void Function(TaskSession session, AgentCli cli) onDispatchTo;
  final void Function(TaskSession session) onDispatchToAll;
  final void Function(TaskSession session) onClone;
  final Future<void> Function(int id, String? notes) onUpdateNotes;
  final Future<void> Function(int id, String? colorLabel) onUpdateColorLabel;
  final void Function(TaskSession session)? onContinueHere;
  final void Function(TaskSession session)? onInjectMessage;
  final VoidCallback onNewTask;
  final VoidCallback? onClearFinished;
  final Set<int> pinnedIds;
  final void Function(int id) onTogglePin;
  final AgentCli? Function(int sessionId)? chainTargetOf;
  final void Function(int sessionId, AgentCli? cli)? onChainTo;

  const TaskPanel({
    super.key,
    required this.sessionsStream,
    required this.terminals,
    required this.searchQuery,
    required this.agents,
    required this.selectedAgentIds,
    required this.onToggleAgent,
    required this.onClearAgents,
    required this.agentNameOf,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onDispatchTo,
    required this.onDispatchToAll,
    required this.onClone,
    required this.onUpdateNotes,
    required this.onUpdateColorLabel,
    this.onContinueHere,
    this.onInjectMessage,
    required this.onNewTask,
    this.onClearFinished,
    required this.pinnedIds,
    required this.onTogglePin,
    this.chainTargetOf,
    this.onChainTo,
  });

  /// Key for the inline task search field (used by widget tests).
  static const Key searchFieldKey = Key('task_panel_search');

  @override
  State<TaskPanel> createState() => _TaskPanelState();
}

class _TaskPanelState extends State<TaskPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _listFocusNode = FocusNode();
  int _focusedIndex = -1;
  /// null = no filter (show all); non-null = show only sessions with that status.
  /// The value 'failed' matches both 'failed' and 'cancelled'.
  String? _statusFilter;
  /// Current secondary sort order (within pinned / unpinned groups).
  /// Values: 'newest' (default), 'oldest', 'name', 'duration'.
  String _sortOrder = 'newest';
  /// Whether to group sessions by working directory.
  bool _groupByDir = false;

  @override
  void dispose() {
    _searchController.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  bool _matches(TaskSession s) {
    // Status filter
    if (_statusFilter != null) {
      if (_statusFilter == 'failed') {
        if (s.status != 'failed' && s.status != 'cancelled') return false;
      } else if (s.status != _statusFilter) {
        return false;
      }
    }
    if (widget.selectedAgentIds.isNotEmpty &&
        !widget.selectedAgentIds.contains(s.agentCliId)) {
      return false;
    }
    final name = s.name.toLowerCase();
    final input = (s.input ?? '').toLowerCase();
    final notes = (s.notes ?? '').toLowerCase();

    bool textMatch(String q) =>
        name.contains(q) || input.contains(q) || notes.contains(q);

    final inline = _searchController.text.trim().toLowerCase();
    if (inline.isNotEmpty && !textMatch(inline)) return false;
    final global = widget.searchQuery.trim().toLowerCase();
    return global.isEmpty || textMatch(global);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: widget.terminals,
      builder: (context, _) {
        final runningCount =
            widget.terminals.openTerminals.where((t) => t.running).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Section header with running badge + stats ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  12, 12, 12, AppSpacing.sectionGap),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      l10n.tasksSection,
                      style: AppTypography.sectionHeader,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SessionStats(
                    sessionsStream: widget.sessionsStream,
                    runningCount: runningCount,
                    l10n: l10n,
                  ),
                  if (runningCount >= 1) ...[
                    const SizedBox(width: 2),
                    _BroadcastButton(terminals: widget.terminals),
                  ],
                  const SizedBox(width: 4),
                  _GroupByDirButton(
                    active: _groupByDir,
                    onToggle: () => setState(() => _groupByDir = !_groupByDir),
                  ),
                  const SizedBox(width: 2),
                  _SortButton(
                    sortOrder: _sortOrder,
                    onChanged: (o) => setState(() => _sortOrder = o),
                  ),
                ],
              ),
            ),

            // --- Inline task search ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                height: 30,
                child: TextField(
                  key: TaskPanel.searchFieldKey,
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.text200,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 7),
                    hintText: l10n.searchTasks,
                    hintStyle: AppTypography.bodySmall,
                    prefixIcon: const Icon(Icons.search,
                        size: 14, color: AppColors.text500),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 30, minHeight: 30),
                    filled: true,
                    fillColor: AppColors.bg800,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // --- Status filter chips ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: StreamBuilder<List<TaskSession>>(
                stream: widget.sessionsStream,
                builder: (context, snapshot) {
                  final all = snapshot.data ?? [];
                  final runCnt = all.where((s) => s.status == 'running').length;
                  final doneCnt = all.where((s) => s.status == 'completed').length;
                  final failCnt = all.where((s) =>
                      s.status == 'failed' || s.status == 'cancelled').length;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _StatusChip(
                        label: l10n.allAgents,
                        count: all.length,
                        isSelected: _statusFilter == null,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: 4),
                      _StatusChip(
                        label: l10n.statusRunning,
                        count: runCnt,
                        isSelected: _statusFilter == 'running',
                        activeColor: AppColors.emerald500,
                        onTap: () => setState(() => _statusFilter =
                            _statusFilter == 'running' ? null : 'running'),
                      ),
                      const SizedBox(width: 4),
                      _StatusChip(
                        label: l10n.statusCompleted,
                        count: doneCnt,
                        isSelected: _statusFilter == 'completed',
                        onTap: () => setState(() => _statusFilter =
                            _statusFilter == 'completed' ? null : 'completed'),
                      ),
                      if (failCnt > 0) ...[const SizedBox(width: 4),
                        _StatusChip(
                          label: l10n.statusFailed,
                          count: failCnt,
                          isSelected: _statusFilter == 'failed',
                          activeColor: AppColors.red400,
                          onTap: () => setState(() => _statusFilter =
                              _statusFilter == 'failed' ? null : 'failed'),
                        ),
                      ],
                    ]),
                  );
                },
              ),
            ),

            // --- Agent-type filter dropdown ---
            if (widget.agents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _AgentFilterDropdown(
                  agents: widget.agents,
                  selectedIds: widget.selectedAgentIds,
                  allLabel: l10n.allAgents,
                  onToggle: widget.onToggleAgent,
                  onClearAll: widget.onClearAgents,
                ),
              ),

            // --- Task list ---
            Expanded(
              child: StreamBuilder<List<TaskSession>>(
                stream: widget.sessionsStream,
                builder: (context, snapshot) {
                  final sessions =
                      (snapshot.data ?? []).where(_matches).toList();
                  if (sessions.isEmpty) {
                    return Center(
                      child: Text(l10n.noSessionsYet,
                          style: AppTypography.bodySmall),
                    );
                  }
                  final allSessions = snapshot.data ?? [];
                  final hasFinished = allSessions.any((s) =>
                      s.status == 'completed' ||
                      s.status == 'failed' ||
                      s.status == 'cancelled');
                  return KeyboardListener(
                    focusNode: _listFocusNode,
                    onKeyEvent: (event) {
                      if (event is! KeyDownEvent) return;
                      if (sessions.isEmpty) return;
                      final len = sessions.length;
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        setState(() => _focusedIndex =
                            (_focusedIndex + 1).clamp(0, len - 1));
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowUp) {
                        setState(() => _focusedIndex =
                            (_focusedIndex - 1).clamp(0, len - 1));
                      } else if (event.logicalKey == LogicalKeyboardKey.enter &&
                          _focusedIndex >= 0 &&
                          _focusedIndex < len) {
                        widget.onOpen(sessions[_focusedIndex]);
                      } else if ((event.logicalKey ==
                                  LogicalKeyboardKey.backspace ||
                              event.logicalKey == LogicalKeyboardKey.delete) &&
                          _focusedIndex >= 0 &&
                          _focusedIndex < len) {
                        widget.onDelete(sessions[_focusedIndex]);
                      }
                    },
                    child: _TaskListBody(
                    sessions: sessions,
                    focusedIndex: _focusedIndex,
                    allHasFinished: hasFinished,
                    terminals: widget.terminals,
                    agents: widget.agents,
                    agentNameOf: widget.agentNameOf,
                    onOpen: widget.onOpen,
                    onDelete: widget.onDelete,
                    onRename: widget.onRename,
                    onDispatchTo: widget.onDispatchTo,
                    onDispatchToAll: widget.onDispatchToAll,
                    onClone: widget.onClone,
                    onUpdateNotes: widget.onUpdateNotes,
                    onUpdateColorLabel: widget.onUpdateColorLabel,
                    onContinueHere: widget.onContinueHere,
                    onInjectMessage: widget.onInjectMessage,
                    onNewTask: widget.onNewTask,
                    onClearFinished: widget.onClearFinished,
                    pinnedIds: widget.pinnedIds,
                    onTogglePin: widget.onTogglePin,
                    sortOrder: _sortOrder,
                    groupByDir: _groupByDir,
                    chainTargetOf: widget.chainTargetOf,
                    onChainTo: widget.onChainTo,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskListBody extends StatelessWidget {
  final List<TaskSession> sessions;
  final int focusedIndex;
  final bool allHasFinished;
  final TerminalSessionsController terminals;
  final List<AgentCli> agents;
  final String Function(String) agentNameOf;
  final void Function(TaskSession) onOpen;
  final void Function(TaskSession) onDelete;
  final void Function(TaskSession, String) onRename;
  final void Function(TaskSession, AgentCli) onDispatchTo;
  final void Function(TaskSession) onDispatchToAll;
  final void Function(TaskSession) onClone;
  final Future<void> Function(int id, String? notes) onUpdateNotes;
  final Future<void> Function(int id, String? colorLabel) onUpdateColorLabel;
  final void Function(TaskSession)? onContinueHere;
  final void Function(TaskSession)? onInjectMessage;
  final VoidCallback onNewTask;
  final VoidCallback? onClearFinished;
  final Set<int> pinnedIds;
  final void Function(int id) onTogglePin;
  final String sortOrder;
  final bool groupByDir;
  final AgentCli? Function(int sessionId)? chainTargetOf;
  final void Function(int sessionId, AgentCli? cli)? onChainTo;

  const _TaskListBody({
    required this.sessions,
    required this.focusedIndex,
    required this.allHasFinished,
    required this.terminals,
    required this.agents,
    required this.agentNameOf,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onDispatchTo,
    required this.onDispatchToAll,
    required this.onClone,
    required this.onUpdateNotes,
    required this.onUpdateColorLabel,
    this.onContinueHere,
    this.onInjectMessage,
    required this.onNewTask,
    this.onClearFinished,
    required this.pinnedIds,
    required this.onTogglePin,
    this.sortOrder = 'newest',
    this.groupByDir = false,
    this.chainTargetOf,
    this.onChainTo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // --- Task list ---
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Text(l10n.noSessionsYet,
                      style: AppTypography.bodySmall))
              : Builder(builder: (context) {
                  // Cluster map: batchId → sessions that share it.
                  final clusterGroups = <String, List<TaskSession>>{};
                  for (final s in sessions) {
                    if (s.batchId != null) {
                      clusterGroups.putIfAbsent(s.batchId!, () => []).add(s);
                    }
                  }
                  int clusterSizeOf(TaskSession s) =>
                      s.batchId != null
                          ? (clusterGroups[s.batchId!]?.length ?? 1)
                          : 1;
                  VoidCallback? onViewClusterOf(
                      BuildContext ctx, TaskSession s) {
                    final siblings = s.batchId != null
                        ? clusterGroups[s.batchId!]
                        : null;
                    if (siblings == null || siblings.length < 2) return null;
                    return () => ClusterComparisonDialog.show(
                          ctx,
                          sessions: siblings,
                          agentNameOf: agentNameOf,
                          onOpen: onOpen,
                          terminals: terminals,
                        );
                  }

                  // Apply chosen secondary sort, then float pinned to top.
                  final displayed = [...sessions];
                  switch (sortOrder) {
                    case 'oldest':
                      displayed.sort((a, b) =>
                          a.createdAt.compareTo(b.createdAt));
                    case 'name':
                      displayed.sort((a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    case 'duration':
                      displayed.sort((a, b) =>
                          (b.durationMs ?? 0).compareTo(a.durationMs ?? 0));
                    default: // 'newest' — DB already ordered by createdAt DESC
                      break;
                  }
                  // Float pinned sessions to the top (stable within sort group).
                  displayed.sort((a, b) {
                    final ap = pinnedIds.contains(a.id);
                    final bp = pinnedIds.contains(b.id);
                    if (ap == bp) return 0;
                    return ap ? -1 : 1;
                  });

                  if (groupByDir) {
                    return _GroupedListView(
                      sessions: displayed,
                      terminals: terminals,
                      agents: agents,
                      agentNameOf: agentNameOf,
                      focusedIndex: focusedIndex,
                      pinnedIds: pinnedIds,
                      onOpen: onOpen,
                      onDelete: onDelete,
                      onRename: onRename,
                      onDispatchTo: onDispatchTo,
                      onDispatchToAll: onDispatchToAll,
                      onClone: onClone,
                      onUpdateNotes: onUpdateNotes,
                      onUpdateColorLabel: onUpdateColorLabel,
                      onContinueHere: onContinueHere,
                      onInjectMessage: onInjectMessage,
                      onTogglePin: onTogglePin,
                      clusterSizeOf: clusterSizeOf,
                      clusterGroups: clusterGroups,
                      chainTargetOf: chainTargetOf,
                      onChainTo: onChainTo,
                    );
                  }

                  final displayedIdSet = {for (final s in displayed) s.id};
                  return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  itemCount: displayed.length,
                  itemBuilder: (context, index) {
                    final s = displayed[index];
                    return _TaskItem(
                      session: s,
                      agentName: agentNameOf(s.agentCliId),
                      status: terminals.statusOf(s.id) ?? s.status,
                      isActive: terminals.activeId == s.id,
                      isOpen: terminals.isOpen(s.id),
                      isKeyboardFocused: index == focusedIndex,
                      hasUnread: terminals.hasUnread(s.id),
                      agents: agents,
                      isPinned: pinnedIds.contains(s.id),
                      colorLabel: s.colorLabel,
                      clusterSize: clusterSizeOf(s),
                      onViewCluster: onViewClusterOf(context, s),
                      onTap: () => onOpen(s),
                      onDelete: () => onDelete(s),
                      onRename: (name) => onRename(s, name),
                      onDispatchTo: (cli) => onDispatchTo(s, cli),
                      onDispatchToAll: () => onDispatchToAll(s),
                      onClone: () => onClone(s),
                      onUpdateNotes: (notes) => onUpdateNotes(s.id, notes),
                      onUpdateColorLabel: (label) => onUpdateColorLabel(s.id, label),
                      onTogglePin: () => onTogglePin(s.id),
                      onContinueHere: onContinueHere != null &&
                              s.workingDirectory != null &&
                              s.workingDirectory!.isNotEmpty
                          ? () => onContinueHere!(s)
                          : null,
                      onInjectMessage: onInjectMessage != null
                          ? () => onInjectMessage!(s)
                          : null,
                      chainTarget: chainTargetOf?.call(s.id),
                      onChainTo: onChainTo != null
                          ? (cli) => onChainTo!(s.id, cli)
                          : null,
                      isChainChild: s.parentSessionId != null &&
                          displayedIdSet.contains(s.parentSessionId),
                    );
                  },
                );
                },),
        ),

        // --- Footer: New task + optional Clear ---
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNewTask,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.newTask),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text400,
                    side: const BorderSide(color: AppColors.border700),
                    backgroundColor: AppColors.accent5,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                    ),
                  ),
                ),
              ),
              // Retry all failed — shown when ≥1 open terminal has failed.
              Builder(builder: (ctx) {
                final failedOpen = terminals.openTerminals
                    .where((t) => t.effectiveStatus == 'failed')
                    .toList();
                if (failedOpen.isEmpty) return const SizedBox.shrink();
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 8),
                  Tooltip(
                    message: AppLocalizations.of(ctx)!.retryAllFailed,
                    child: OutlinedButton(
                      onPressed: () {
                        for (final t in List.of(failedOpen)) {
                          unawaited(terminals.relaunch(t.sessionId));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent400,
                        side: const BorderSide(
                            color: AppColors.accent400),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.inputRadius),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.replay, size: 14),
                        const SizedBox(width: 4),
                        Text('${failedOpen.length}',
                            style: AppTypography.monoSmall.copyWith(
                                color: AppColors.accent400)),
                      ]),
                    ),
                  ),
                ]);
              }),
              if (allHasFinished && onClearFinished != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: AppLocalizations.of(context)!.clearFinishedSessions,
                  child: OutlinedButton(
                    key: TaskPanel.clearButtonKey,
                    onPressed: onClearFinished,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text500,
                      side: const BorderSide(color: AppColors.border700),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppSpacing.inputRadius),
                      ),
                    ),
                    child: const Icon(Icons.delete_sweep_outlined,
                        size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group-by-directory toggle button
// ─────────────────────────────────────────────────────────────────────────────

class _GroupByDirButton extends StatefulWidget {
  final bool active;
  final VoidCallback onToggle;

  const _GroupByDirButton({required this.active, required this.onToggle});

  @override
  State<_GroupByDirButton> createState() => _GroupByDirButtonState();
}

class _GroupByDirButtonState extends State<_GroupByDirButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.groupByProject,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(
              widget.active
                  ? Icons.folder_copy_rounded
                  : Icons.folder_outlined,
              size: 14,
              color: widget.active
                  ? AppColors.accent400
                  : _hovered
                      ? AppColors.text200
                      : AppColors.text500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouped list view — sessions bucketed by workingDirectory
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedListView extends StatefulWidget {
  final List<TaskSession> sessions;
  final TerminalSessionsController terminals;
  final List<AgentCli> agents;
  final String Function(String) agentNameOf;
  final int focusedIndex;
  final Set<int> pinnedIds;
  final void Function(TaskSession) onOpen;
  final void Function(TaskSession) onDelete;
  final void Function(TaskSession, String) onRename;
  final void Function(TaskSession, AgentCli) onDispatchTo;
  final void Function(TaskSession) onDispatchToAll;
  final void Function(TaskSession) onClone;
  final Future<void> Function(int id, String? notes) onUpdateNotes;
  final Future<void> Function(int id, String? colorLabel) onUpdateColorLabel;
  final void Function(TaskSession)? onContinueHere;
  final void Function(TaskSession)? onInjectMessage;
  final void Function(int id) onTogglePin;
  final int Function(TaskSession) clusterSizeOf;
  final Map<String, List<TaskSession>> clusterGroups;
  final AgentCli? Function(int sessionId)? chainTargetOf;
  final void Function(int sessionId, AgentCli? cli)? onChainTo;

  const _GroupedListView({
    required this.sessions,
    required this.terminals,
    required this.agents,
    required this.agentNameOf,
    required this.focusedIndex,
    required this.pinnedIds,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onDispatchTo,
    required this.onDispatchToAll,
    required this.onClone,
    required this.onUpdateNotes,
    required this.onUpdateColorLabel,
    this.onContinueHere,
    this.onInjectMessage,
    required this.onTogglePin,
    required this.clusterSizeOf,
    required this.clusterGroups,
    this.chainTargetOf,
    this.onChainTo,
  });

  @override
  State<_GroupedListView> createState() => _GroupedListViewState();
}

class _GroupedListViewState extends State<_GroupedListView> {
  /// Set of group keys that the user has collapsed.
  final Set<String> _collapsed = {};

  /// Build an ordered list of (groupKey, [sessions]) pairs.
  /// Named groups sorted alphabetically, the empty/"Other" group last.
  List<MapEntry<String, List<TaskSession>>> _buildGroups() {
    final map = <String, List<TaskSession>>{};
    for (final s in widget.sessions) {
      final key =
          (s.workingDirectory != null && s.workingDirectory!.isNotEmpty)
              ? s.workingDirectory!
              : '';
      (map[key] ??= []).add(s);
    }
    final named = map.keys.where((k) => k.isNotEmpty).toList()
      ..sort((a, b) => p.basename(a).toLowerCase()
          .compareTo(p.basename(b).toLowerCase()));
    final ordered = [...named, if (map.containsKey('')) ''];
    return ordered.map((k) => MapEntry(k, map[k]!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = _buildGroups();

    // Build a flat list of items: headers + (visible) sessions.
    final items = <_GroupListEntry>[];
    for (final entry in groups) {
      final key = entry.key;
      final groupSessions = entry.value;
      final collapsed = _collapsed.contains(key);
      items.add(_GroupListEntry.header(
        key: key,
        count: groupSessions.length,
        collapsed: collapsed,
      ));
      if (!collapsed) {
        for (final s in groupSessions) {
          items.add(_GroupListEntry.session(s));
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          final dirName = item.groupKey!.isEmpty
              ? l10n.groupOther
              : p.basename(item.groupKey!);
          return _GroupHeader(
            dirName: dirName,
            fullPath: item.groupKey!.isEmpty ? null : item.groupKey!,
            count: item.count,
            collapsed: item.collapsed,
            onToggle: () => setState(() {
              if (_collapsed.contains(item.groupKey!)) {
                _collapsed.remove(item.groupKey!);
              } else {
                _collapsed.add(item.groupKey!);
              }
            }),
          );
        }
        final s = item.session!;
        return _TaskItem(
          session: s,
          agentName: widget.agentNameOf(s.agentCliId),
          status: widget.terminals.statusOf(s.id) ?? s.status,
          isActive: widget.terminals.activeId == s.id,
          isOpen: widget.terminals.isOpen(s.id),
          isKeyboardFocused: false,
          hasUnread: widget.terminals.hasUnread(s.id),
          agents: widget.agents,
          isPinned: widget.pinnedIds.contains(s.id),
          colorLabel: s.colorLabel,
          clusterSize: widget.clusterSizeOf(s),
          onViewCluster: () {
            final siblings =
                s.batchId != null ? widget.clusterGroups[s.batchId!] : null;
            if (siblings == null || siblings.length < 2) return;
            ClusterComparisonDialog.show(
              context,
              sessions: siblings,
              agentNameOf: widget.agentNameOf,
              onOpen: widget.onOpen,
              terminals: widget.terminals,
            );
          },
          onTap: () => widget.onOpen(s),
          onDelete: () => widget.onDelete(s),
          onRename: (name) => widget.onRename(s, name),
          onDispatchTo: (cli) => widget.onDispatchTo(s, cli),
          onDispatchToAll: () => widget.onDispatchToAll(s),
          onClone: () => widget.onClone(s),
          onUpdateNotes: (notes) => widget.onUpdateNotes(s.id, notes),
          onUpdateColorLabel: (label) =>
              widget.onUpdateColorLabel(s.id, label),
          onTogglePin: () => widget.onTogglePin(s.id),
          onContinueHere: widget.onContinueHere != null &&
                  s.workingDirectory != null &&
                  s.workingDirectory!.isNotEmpty
              ? () => widget.onContinueHere!(s)
              : null,
          onInjectMessage: widget.onInjectMessage != null
              ? () => widget.onInjectMessage!(s)
              : null,
          chainTarget: widget.chainTargetOf?.call(s.id),
          onChainTo: widget.onChainTo != null
              ? (cli) => widget.onChainTo!(s.id, cli)
              : null,
          isChainChild: s.parentSessionId != null &&
              widget.sessions.any((p) => p.id == s.parentSessionId),
        );
      },
    );
  }
}

/// Flat list entry — either a group header or a session row.
class _GroupListEntry {
  final bool isHeader;
  final String? groupKey;
  final int count;
  final bool collapsed;
  final TaskSession? session;

  const _GroupListEntry.header({
    required String key,
    required this.count,
    required this.collapsed,
  })  : isHeader = true,
        groupKey = key,
        session = null;

  const _GroupListEntry.session(TaskSession s)
      : isHeader = false,
        groupKey = null,
        count = 0,
        collapsed = false,
        session = s;
}

/// Collapsible group header showing the directory name and session count.
/// Hover-revealed button on a project group header that opens the shared
/// project memory editor for that directory.
class _BroadcastButton extends StatelessWidget {
  final TerminalSessionsController terminals;

  const _BroadcastButton({required this.terminals});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.broadcastTooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        onTap: () => BroadcastDialog.show(context, terminals),
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.hub_outlined, size: 13, color: AppColors.emerald500),
        ),
      ),
    );
  }
}

class _SharedMemoryButton extends StatelessWidget {
  final String projectPath;

  const _SharedMemoryButton({required this.projectPath});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.sharedMemoryTooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        onTap: () => SharedMemoryDialog.show(context, projectPath),
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.psychology_outlined,
              size: 13, color: AppColors.text500),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatefulWidget {
  final String dirName;
  final String? fullPath;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  const _GroupHeader({
    required this.dirName,
    this.fullPath,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tooltip = widget.fullPath ?? widget.dirName;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onToggle,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            margin: const EdgeInsets.only(bottom: 2, top: 4),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.bg800 : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
            child: Row(children: [
              AnimatedRotation(
                turns: widget.collapsed ? -0.25 : 0,
                duration: AppSpacing.fastTransition,
                child: const Icon(Icons.expand_more,
                    size: 14, color: AppColors.text500),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.folder_outlined,
                  size: 12, color: AppColors.text500),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.dirName,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.text400,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.fullPath != null && _hovered) ...[
                _SharedMemoryButton(projectPath: widget.fullPath!),
                const SizedBox(width: 4),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bg900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.count}',
                  style: AppTypography.meta.copyWith(color: AppColors.text500),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Compact multi-select agent filter dropdown.
///
/// Shows a button summarising the current filter; on tap opens a popup
/// menu with a checkbox for each agent so the user can toggle multiple
/// agents without the menu closing between selections.
class _AgentFilterDropdown extends StatelessWidget {
  final List<AgentCli> agents;
  final Set<String> selectedIds;
  final String allLabel;
  final ValueChanged<String> onToggle;
  final VoidCallback onClearAll;

  const _AgentFilterDropdown({
    required this.agents,
    required this.selectedIds,
    required this.allLabel,
    required this.onToggle,
    required this.onClearAll,
  });

  String get _buttonLabel {
    if (selectedIds.isEmpty) return allLabel;
    final names = agents
        .where((a) => selectedIds.contains(a.id))
        .map((a) => a.displayName)
        .join(', ');
    return names.length > 26 ? '${names.substring(0, 24)}…' : names;
  }

  bool get _isFiltered => selectedIds.isNotEmpty;

  Future<void> _showMenu(BuildContext ctx) async {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Navigator.of(ctx).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final pos = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 4,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );

    // Local copy so checkboxes update immediately without waiting for the
    // parent setState to propagate.
    final localSelected = Set<String>.from(selectedIds);

    await showMenu<void>(
      context: ctx,
      position: pos,
      color: AppColors.bg800,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        side: const BorderSide(color: AppColors.border700),
      ),
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (_, setMenuState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "All agents" row
                _CheckRow(
                  label: allLabel,
                  checked: localSelected.isEmpty,
                  onTap: () {
                    setMenuState(() => localSelected.clear());
                    onClearAll();
                  },
                ),
                const Divider(height: 1, color: AppColors.border700),
                for (final agent in agents)
                  _CheckRow(
                    label: agent.displayName,
                    checked: localSelected.contains(agent.id),
                    onTap: () {
                      setMenuState(() {
                        if (localSelected.contains(agent.id)) {
                          localSelected.remove(agent.id);
                          if (localSelected.isEmpty) onClearAll();
                        } else {
                          localSelected.add(agent.id);
                        }
                      });
                      onToggle(agent.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => GestureDetector(
        onTap: () => _showMenu(ctx),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: AppSpacing.fastTransition,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _isFiltered ? AppColors.accent10 : AppColors.bg800,
              borderRadius:
                  BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                color: _isFiltered
                    ? AppColors.accent400
                    : AppColors.border700,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 13,
                  color: _isFiltered
                      ? AppColors.accent400
                      : AppColors.text400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _buttonLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _isFiltered
                          ? AppColors.accent400
                          : AppColors.text400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: _isFiltered
                      ? AppColors.accent400
                      : AppColors.text400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single checkbox row inside the agent filter popup menu.
class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppSpacing.fastTransition,
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: checked ? AppColors.accent400 : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: checked
                      ? AppColors.accent400
                      : AppColors.border700,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check,
                      size: 10, color: AppColors.bg950)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color:
                      checked ? AppColors.text200 : AppColors.text400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem extends StatefulWidget {
  final TaskSession session;
  final String agentName;
  final String status;
  final bool isActive;
  final bool isOpen;
  final bool isKeyboardFocused;
  final bool hasUnread;
  final List<AgentCli> agents;
  final bool isPinned;
  final String? colorLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<String> onRename;
  final void Function(AgentCli) onDispatchTo;
  final VoidCallback onDispatchToAll;
  final VoidCallback onClone;
  final Future<void> Function(String? notes) onUpdateNotes;
  final Future<void> Function(String? colorLabel) onUpdateColorLabel;
  final VoidCallback onTogglePin;
  /// When non-null, a ↪ button is shown on hover to start a new session
  /// in the same working directory.
  final VoidCallback? onContinueHere;

  /// When non-null and session is running, a send button is shown on hover
  /// to inject a message directly into this agent's stdin.
  final VoidCallback? onInjectMessage;

  /// Number of sessions in this session's cluster batch (1 = solo session).
  /// A badge is shown when this is ≥ 2.
  final int clusterSize;

  /// When non-null, tapping the cluster badge opens the comparison dialog.
  final VoidCallback? onViewCluster;

  /// Auto-relay target: when set, on successful completion the session output
  /// is automatically piped to this agent. Shown as a ⛓ badge in the row.
  final AgentCli? chainTarget;

  /// Set (or clear when null) the auto-relay target for this session.
  /// Only offered as a hover button while the session is running.
  final void Function(AgentCli? cli)? onChainTo;

  /// True when this session's parent is also visible in the list — renders
  /// a tree-connector indent so the relay chain is visually grouped.
  final bool isChainChild;

  const _TaskItem({
    required this.session,
    required this.agentName,
    required this.status,
    required this.isActive,
    required this.isOpen,
    this.isKeyboardFocused = false,
    this.hasUnread = false,
    required this.agents,
    this.isPinned = false,
    this.colorLabel,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onDispatchTo,
    required this.onDispatchToAll,
    required this.onClone,
    required this.onUpdateNotes,
    required this.onUpdateColorLabel,
    required this.onTogglePin,
    this.onContinueHere,
    this.onInjectMessage,
    this.clusterSize = 1,
    this.onViewCluster,
    this.chainTarget,
    this.onChainTo,
    this.isChainChild = false,
  });

  @override
  State<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<_TaskItem> {
  bool _hovered = false;
  bool _editing = false;
  bool _expanded = false;
  late final TextEditingController _nameController;
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<void>? _timerSub;
  DateTime? _timerStart;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commitRename();
    });
    _syncTimer();
  }

  @override
  void didUpdateWidget(_TaskItem old) {
    super.didUpdateWidget(old);
    if (!_editing && old.session.name != widget.session.name) {
      _nameController.text = widget.session.name;
    }
    if (old.status != widget.status) _syncTimer();
  }

  @override
  void dispose() {
    _timerSub?.cancel();
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncTimer() {
    if (widget.status == 'running') {
      _timerStart ??= widget.session.createdAt;
      _timerSub ??= Stream.periodic(const Duration(seconds: 1))
          .listen((_) { if (mounted) setState(() {}); });
    } else {
      _timerSub?.cancel();
      _timerSub = null;
      _timerStart = null;
    }
  }

  String _elapsed() {
    final start = _timerStart ?? widget.session.createdAt;
    final d = DateTime.now().difference(start);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0
        ? '${m}m ${s.toString().padLeft(2, '0')}s'
        : '${s}s';
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _nameController.selection = TextSelection(
          baseOffset: 0, extentOffset: _nameController.text.length);
    });
    // Let the field render before requesting focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _showContextMenu(BuildContext context, Offset pos) async {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;
    final hasDir = session.workingDirectory != null &&
        session.workingDirectory!.isNotEmpty;
    final hasPrompt =
        session.input != null && session.input!.trim().isNotEmpty;
    final hasOutput =
        session.output != null && session.output!.trim().isNotEmpty;
    final canContinue = widget.onContinueHere != null && hasDir;

    // Build other-agent items (excluding current agent).
    final otherAgents = widget.agents
        .where((a) => a.id != session.agentCliId && a.detected)
        .toList();

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppColors.bg800,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          side: const BorderSide(color: AppColors.border700)),
      items: [
        if (widget.status == 'running' && widget.onInjectMessage != null) ...[
          PopupMenuItem<String>(
            value: 'inject',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.send_outlined,
                  size: 13, color: AppColors.emerald500),
              const SizedBox(width: 8),
              Text(l10n.injectMessageTooltip,
                  style: AppTypography.body
                      .copyWith(color: AppColors.emerald500)),
            ]),
          ),
          const PopupMenuDivider(height: 1),
        ],
        if (canContinue)
          PopupMenuItem<String>(
            value: 'continue_here',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.subdirectory_arrow_right,
                  size: 13, color: AppColors.accent400),
              const SizedBox(width: 8),
              Text(l10n.newTaskHere,
                  style: AppTypography.body
                      .copyWith(color: AppColors.accent400)),
            ]),
          ),
        PopupMenuItem<String>(
          value: 'clone',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.copy_all_outlined,
                size: 13, color: AppColors.text400),
            const SizedBox(width: 8),
            Text(l10n.cloneSession, style: AppTypography.body),
          ]),
        ),
        if (canContinue && otherAgents.isNotEmpty)
          const PopupMenuDivider(height: 1),
        if (otherAgents.isNotEmpty)
          PopupMenuItem<String>(
            enabled: false,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: Text(l10n.sendToAgent,
                style: AppTypography.meta
                    .copyWith(color: AppColors.text500)),
          ),
        if (otherAgents.length >= 2)
          PopupMenuItem<String>(
            value: 'relay_all',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.share_outlined,
                  size: 13, color: AppColors.accent400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.relayToAll,
                        style: AppTypography.body
                            .copyWith(color: AppColors.accent400)),
                    Text(l10n.relayToAllSubtitle(otherAgents.length),
                        style: AppTypography.meta),
                  ],
                ),
              ),
            ]),
          ),
        for (final agent in otherAgents)
          PopupMenuItem<String>(
            value: 'dispatch:${agent.id}',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.terminal, size: 13, color: AppColors.text400),
              const SizedBox(width: 8),
              Text(agent.displayName, style: AppTypography.body),
            ]),
          ),
        if (otherAgents.isNotEmpty) const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'open_folder',
          enabled: hasDir,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(Icons.folder_open,
                size: 13,
                color: hasDir ? AppColors.text400 : AppColors.text500),
            const SizedBox(width: 8),
            Text(l10n.openInFinder,
                style: AppTypography.body.copyWith(
                    color: hasDir ? null : AppColors.text500)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'copy_prompt',
          enabled: hasPrompt,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(Icons.copy_outlined,
                size: 13,
                color: hasPrompt ? AppColors.text400 : AppColors.text500),
            const SizedBox(width: 8),
            Text(l10n.copyPrompt,
                style: AppTypography.body.copyWith(
                    color: hasPrompt ? null : AppColors.text500)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'copy_output',
          enabled: hasOutput,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(Icons.terminal,
                size: 13,
                color: hasOutput ? AppColors.text400 : AppColors.text500),
            const SizedBox(width: 8),
            Text(l10n.copyOutput,
                style: AppTypography.body.copyWith(
                    color: hasOutput ? null : AppColors.text500)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'export_md',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.download_outlined,
                size: 13, color: AppColors.text400),
            const SizedBox(width: 8),
            Text(l10n.exportAsMarkdown, style: AppTypography.body),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'toggle_pin',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(
              widget.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              size: 13,
              color: AppColors.text400,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isPinned ? l10n.unpinSession : l10n.pinSession,
              style: AppTypography.body,
            ),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'edit_note',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.edit_note_outlined,
                size: 13, color: AppColors.text400),
            const SizedBox(width: 8),
            Text(l10n.editNote, style: AppTypography.body),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'set_color',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.palette_outlined,
                size: 13, color: AppColors.text400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.setColor, style: AppTypography.body),
            ),
            if (widget.colorLabel != null)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.sessionColorLabels[widget.colorLabel!],
                  shape: BoxShape.circle,
                ),
              ),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.delete_outline,
                size: 13, color: AppColors.red400),
            const SizedBox(width: 8),
            Text(l10n.delete,
                style: AppTypography.body
                    .copyWith(color: AppColors.red400)),
          ]),
        ),
      ],
    );

    if (result == null || !context.mounted) return;

    if (result == 'inject') {
      widget.onInjectMessage?.call();
    } else if (result == 'continue_here') {
      widget.onContinueHere?.call();
    } else if (result == 'clone') {
      widget.onClone();
    } else if (result == 'relay_all') {
      widget.onDispatchToAll();
    } else if (result.startsWith('dispatch:')) {
      final agentId = result.substring('dispatch:'.length);
      final agent = widget.agents.firstWhere((a) => a.id == agentId);
      widget.onDispatchTo(agent);
    } else if (result == 'open_folder' && hasDir) {
      await Process.run('open', [session.workingDirectory!]);
    } else if (result == 'copy_prompt' && hasPrompt) {
      await Clipboard.setData(ClipboardData(text: session.input!.trim()));
    } else if (result == 'copy_output' && hasOutput) {
      await Clipboard.setData(ClipboardData(text: session.output!.trim()));
    } else if (result == 'export_md') {
      await _exportSessionAsMarkdown(context);
    } else if (result == 'toggle_pin') {
      widget.onTogglePin();
    } else if (result == 'edit_note') {
      await _showNoteDialog(context);
    } else if (result == 'set_color') {
      await _showColorPicker(context);
    } else if (result == 'delete') {
      widget.onDelete();
    }
  }

  Future<void> _exportSessionAsMarkdown(BuildContext ctx) async {
    await ExportService.exportSession(
      ctx,
      widget.session,
      agentName: widget.agentName,
    );
  }

  Future<void> _showColorPicker(BuildContext ctx) async {
    final l10n = AppLocalizations.of(ctx)!;
    final picked = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bg800,
        title: Text(l10n.setColor, style: AppTypography.cardTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColors.sessionColorLabels.entries.map((e) {
                final isSelected = widget.colorLabel == e.key;
                return GestureDetector(
                  onTap: () => Navigator.of(dialogCtx).pop(e.key),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(
                                color: e.value.withAlpha(80), width: 1),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (widget.colorLabel != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(dialogCtx).pop(''),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(children: [
                    const Icon(Icons.close, size: 13, color: AppColors.text400),
                    const SizedBox(width: 6),
                    Text(l10n.clearColor,
                        style: AppTypography.body
                            .copyWith(color: AppColors.text400)),
                  ]),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.text400),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await widget.onUpdateColorLabel(picked.isEmpty ? null : picked);
  }

  Future<void> _showNoteDialog(BuildContext ctx) async {
    final l10n = AppLocalizations.of(ctx)!;
    final ctl = TextEditingController(
        text: widget.session.notes ?? '');
    final saved = await showDialog<String?>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bg800,
        title: Text(l10n.editNote, style: AppTypography.cardTitle),
        content: TextField(
          controller: ctl,
          maxLines: 5,
          autofocus: true,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: l10n.notePlaceholder,
            hintStyle: AppTypography.meta,
            filled: true,
            fillColor: AppColors.bg900,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent400),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.text400),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(ctl.text),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.accent400),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (saved == null) return; // user cancelled
    final trimmed = saved.trim();
    await widget.onUpdateNotes(trimmed.isEmpty ? null : trimmed);
  }

  void _commitRename() {
    final name = _nameController.text.trim();
    setState(() => _editing = false);
    if (name.isNotEmpty && name != widget.session.name) {
      widget.onRename(name);
    } else {
      _nameController.text = widget.session.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? AppColors.accent10
        : widget.isKeyboardFocused
            ? AppColors.bg800
            : _hovered
                ? AppColors.bg800
                : Colors.transparent;

    final labelColor = widget.colorLabel != null
        ? AppColors.sessionColorLabels[widget.colorLabel!]
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: _editing ? SystemMouseCursors.text : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: AppSpacing.fastTransition,
        margin: EdgeInsets.only(
          bottom: AppSpacing.itemGap,
          left: widget.isChainChild ? 14.0 : 0.0,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.sidebarItemRadius),
          border: _editing
              ? Border.all(color: AppColors.accent400, width: 1)
              : labelColor != null
                  ? Border(
                      left: BorderSide(color: labelColor, width: 3))
                  : widget.isChainChild
                      ? Border(
                          left: BorderSide(
                              color: AppColors.emerald500.withAlpha(80),
                              width: 2))
                      : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Main row ---
            GestureDetector(
              onTap: _editing ? null : widget.onTap,
              onDoubleTap: _startEdit,
              onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sidebarItemPaddingH,
                  vertical: AppSpacing.sidebarItemPaddingV,
                ),
                child: Row(
                  children: [
                    if (widget.isChainChild) ...[
                      const Icon(Icons.subdirectory_arrow_right_outlined,
                          size: 11,
                          color: Color(0x9910b981)), // emerald, 60% alpha
                      const SizedBox(width: 4),
                    ],
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusDotColor(widget.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_editing)
                            TextField(
                              controller: _nameController,
                              focusNode: _focusNode,
                              style: AppTypography.sidebarItem(selected: true)
                                  .copyWith(fontSize: 13),
                              cursorColor: AppColors.accent400,
                              cursorWidth: 1.5,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _commitRename(),
                              onEditingComplete: _commitRename,
                              onTapOutside: (_) => _commitRename(),
                            )
                          else
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.session.name,
                                    style: AppTypography.sidebarItem(
                                        selected: widget.isActive),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Unread-output dot (background terminal
                                // produced output since last viewed)
                                if (widget.hasUnread &&
                                    !widget.isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                if (widget.isPinned && !_hovered) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.push_pin,
                                      size: 9,
                                      color: AppColors.accent400),
                                ],
                                // Cluster badge: shown when this session was
                                // created as part of a multi-agent batch run.
                                // Tapping opens the cluster comparison dialog.
                                if (widget.clusterSize > 1) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: 'Cluster run · ${widget.clusterSize} agents — tap to compare',
                                    waitDuration: const Duration(milliseconds: 400),
                                    child: GestureDetector(
                                      onTap: widget.onViewCluster,
                                      child: MouseRegion(
                                        cursor: widget.onViewCluster != null
                                            ? SystemMouseCursors.click
                                            : SystemMouseCursors.basic,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent400.withAlpha(30),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                                color: AppColors.accent400.withAlpha(80)),
                                          ),
                                          child: Text(
                                            '×${widget.clusterSize}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.accent400,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Menlo',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                // Auto-relay chain badge — tap to clear.
                                if (widget.chainTarget != null) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message:
                                        '⛓ Auto-relay → ${widget.chainTarget!.displayName} (tap to cancel)',
                                    waitDuration: const Duration(milliseconds: 300),
                                    child: GestureDetector(
                                      onTap: () => widget.onChainTo?.call(null),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.emerald500.withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: AppColors.emerald500
                                                    .withAlpha(80)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.link,
                                                  size: 8,
                                                  color: AppColors.emerald500),
                                              const SizedBox(width: 2),
                                              Text(
                                                widget.chainTarget!.displayName,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.emerald500,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'Menlo',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                // Workflow badge — shown when session belongs to a DAG workflow run.
                                if (widget.session.workflowRunId != null &&
                                    widget.session.workflowRunId!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: 'Part of a workflow run',
                                    waitDuration: const Duration(milliseconds: 300),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent400.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: AppColors.accent400.withAlpha(60)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.account_tree,
                                              size: 8, color: AppColors.accent400),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.agentName,
                                  style: AppTypography.meta,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.status == 'running')
                                Text(
                                  _elapsed(),
                                  style: AppTypography.meta.copyWith(
                                    color: AppColors.emerald500,
                                    fontFamily: 'Menlo',
                                  ),
                                )
                              else if ((widget.status ==
                                          'completed' ||
                                      widget.status == 'failed') &&
                                  widget.session.durationMs != null)
                                Text(
                                  _formatDurationMs(
                                      widget.session.durationMs),
                                  style: AppTypography.meta.copyWith(
                                    color: widget.status == 'completed'
                                        ? AppColors.text500
                                        : AppColors.red400,
                                    fontFamily: 'Menlo',
                                  ),
                                ),
                            ],
                          ),
                          if (!_editing &&
                              widget.session.input != null &&
                              widget.session.input!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.session.input!.trim(),
                                style: AppTypography.meta.copyWith(
                                  color: AppColors.text500,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_hovered && !_editing) ...[
                      if (widget.status == 'failed' ||
                          widget.status == 'cancelled') ...[
                        Tooltip(
                          message: AppLocalizations.of(context)!.retrySession,
                          waitDuration: const Duration(milliseconds: 400),
                          child: GestureDetector(
                            onTap: widget.onClone,
                            child: const Icon(Icons.replay,
                                size: AppSpacing.iconSm,
                                color: AppColors.accent400),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (widget.status == 'running' && widget.onChainTo != null) ...[
                        _ChainButton(
                          agents: widget.agents,
                          currentTarget: widget.chainTarget,
                          onSelect: widget.onChainTo!,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (widget.status == 'running' && widget.onInjectMessage != null)
                        Tooltip(
                          message: AppLocalizations.of(context)!.injectMessageTooltip,
                          waitDuration: const Duration(milliseconds: 400),
                          child: GestureDetector(
                            onTap: widget.onInjectMessage,
                            child: const Icon(Icons.send_outlined,
                                size: AppSpacing.iconSm,
                                color: AppColors.emerald500),
                          ),
                        ),
                      if (widget.status == 'running' && widget.onInjectMessage != null)
                        const SizedBox(width: 6),
                      if (widget.onContinueHere != null)
                        Tooltip(
                          message: AppLocalizations.of(context)!.newTaskSameFolder,
                          child: GestureDetector(
                            onTap: widget.onContinueHere,
                            child: const Icon(Icons.subdirectory_arrow_right,
                                size: AppSpacing.iconSm,
                                color: AppColors.accent400),
                          ),
                        ),
                      if (widget.onContinueHere != null)
                        const SizedBox(width: 6),
                      Tooltip(
                        message: widget.isPinned
                            ? AppLocalizations.of(context)!.unpinSession
                            : AppLocalizations.of(context)!.pinSession,
                        child: GestureDetector(
                          onTap: widget.onTogglePin,
                          child: Icon(
                            widget.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: AppSpacing.iconSm,
                            color: widget.isPinned
                                ? AppColors.accent400
                                : AppColors.text500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _startEdit,
                        child: const Icon(Icons.edit_outlined,
                            size: AppSpacing.iconSm,
                            color: AppColors.text500),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: const Icon(Icons.delete_outline,
                            size: AppSpacing.iconSm,
                            color: AppColors.text500),
                      ),
                      const SizedBox(width: 4),
                    ],
                    // Expand toggle
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: _hovered
                            ? AppColors.text400
                            : AppColors.text500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Detail panel (animated expand) ---
            AnimatedSize(
              duration: AppSpacing.normalTransition,
              curve: Curves.easeOut,
              child: _expanded
                  ? _DetailPanel(session: widget.session)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expanded detail panel showing working directory, duration, and exit code.
/// When the session was created by the auto-relay pipeline, also shows
/// "Relayed from: [parent session name]".
class _DetailPanel extends StatefulWidget {
  final TaskSession session;

  const _DetailPanel({required this.session});

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  String? _parentName;

  @override
  void initState() {
    super.initState();
    if (widget.session.parentSessionId != null) {
      context
          .read<AppDatabase>()
          .getSessionName(widget.session.parentSessionId)
          .then((name) {
        if (mounted) setState(() => _parentName = name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 8, color: AppColors.border800),
          if (_parentName != null)
            _row(Icons.link, 'Relayed from: $_parentName',
                color: AppColors.emerald500),
          if (s.workingDirectory != null && s.workingDirectory!.isNotEmpty)
            _row(
              Icons.folder_open,
              s.workingDirectory!
                  .replaceFirst(RegExp(r'^.*/([^/]+/[^/]+)$'), r'…/\1'),
              tooltip: s.workingDirectory!,
            ),
          _row(Icons.timer_outlined, _formatDurationMs(s.durationMs)),
          if (s.exitCode != null)
            _row(
              s.exitCode == 0
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              AppLocalizations.of(context)!.exitCode(s.exitCode!),
              color: s.exitCode == 0
                  ? AppColors.emerald500
                  : AppColors.red400,
            ),
          _row(
            Icons.schedule_outlined,
            _fmtDate(AppLocalizations.of(context)!, s.createdAt),
          ),
          // User note — shown when a note has been attached.
          if (s.notes != null && s.notes!.isNotEmpty) ...[const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent30),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1, right: 5),
                    child: Icon(Icons.sticky_note_2_outlined,
                        size: 11, color: AppColors.accent400),
                  ),
                  Expanded(
                    child: Text(
                      s.notes!,
                      style: AppTypography.monoSmall.copyWith(
                          color: AppColors.accent400),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Output snippet — visible when the session has captured output.
          if (s.output != null && s.output!.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.border800),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => OutputViewerDialog.show(
                context,
                sessionName: s.name,
                output: s.output!.trim(),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Tooltip(
                  message: AppLocalizations.of(context)!.tapToViewOutput,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.bg800,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.border800),
                    ),
                    child: Text(
                      AnsiUtils.tail(s.output!, maxChars: 300),
                      style: AppTypography.monoSmall
                          .copyWith(color: AppColors.text400),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text,
      {String? tooltip, Color? color}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon,
              size: 11,
              color: color ?? AppColors.text500),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: AppTypography.meta.copyWith(
                color: color ?? AppColors.text500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return tooltip != null
        ? Tooltip(message: tooltip, child: row)
        : row;
  }


}

/// Small hover button that opens an agent picker popup for the auto-relay
/// chain target. Tapping "clear" removes the chain.
class _ChainButton extends StatelessWidget {
  final List<AgentCli> agents;
  final AgentCli? currentTarget;
  final void Function(AgentCli? cli) onSelect;

  const _ChainButton({
    required this.agents,
    required this.currentTarget,
    required this.onSelect,
  });

  Future<void> _showPicker(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final detected = agents.where((a) => a.detected).toList();

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + box.size.height + 4,
        origin.dx + 1,
        0,
      ),
      color: AppColors.bg800,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        side: const BorderSide(color: AppColors.border700),
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'Chain output to…',
            style: AppTypography.meta.copyWith(color: AppColors.text500),
          ),
        ),
        for (final agent in detected)
          PopupMenuItem<String>(
            value: agent.id,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Icon(
                currentTarget?.id == agent.id
                    ? Icons.link
                    : Icons.link_outlined,
                size: 13,
                color: currentTarget?.id == agent.id
                    ? AppColors.emerald500
                    : AppColors.text400,
              ),
              const SizedBox(width: 8),
              Text(
                agent.displayName,
                style: AppTypography.body.copyWith(
                  color: currentTarget?.id == agent.id
                      ? AppColors.emerald500
                      : null,
                ),
              ),
            ]),
          ),
        if (currentTarget != null) ...[
          const PopupMenuDivider(height: 1),
          const PopupMenuItem<String>(
            value: '__clear__',
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Icon(Icons.link_off, size: 13, color: AppColors.text400),
              SizedBox(width: 8),
              Text('Remove chain'),
            ]),
          ),
        ],
      ],
    );

    if (result == null) return;
    if (result == '__clear__') {
      onSelect(null);
    } else {
      final agent = agents.firstWhere((a) => a.id == result);
      onSelect(agent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => Tooltip(
        message: currentTarget != null
            ? '⛓ Chain → ${currentTarget!.displayName}'
            : 'Chain to agent on complete',
        waitDuration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: () => _showPicker(ctx),
          child: Icon(
            currentTarget != null ? Icons.link : Icons.link_outlined,
            size: AppSpacing.iconSm,
            color: currentTarget != null
                ? AppColors.emerald500
                : AppColors.text500,
          ),
        ),
      ),
    );
  }
}

/// A compact status-filter chip in the task panel header.
///
/// Tapping toggles the filter; when selected, the chip shows a tinted border
/// and the provided [activeColor] (defaults to [AppColors.accent400]).
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.isSelected,
    this.activeColor = AppColors.accent400,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppSpacing.fastTransition,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withAlpha(26) : AppColors.bg800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border700,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.meta.copyWith(
                  color: isSelected ? activeColor : AppColors.text400,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppTypography.meta.copyWith(
                    color: isSelected ? activeColor : AppColors.text500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact sort button that opens a popup menu of sort options.
class _SortButton extends StatelessWidget {
  final String sortOrder;
  final ValueChanged<String> onChanged;

  const _SortButton({required this.sortOrder, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      ('newest', l10n.sortNewest),
      ('oldest', l10n.sortOldest),
      ('name', l10n.sortByName),
      ('duration', l10n.sortByDuration),
    ];
    return Tooltip(
      message: l10n.sortLabel,
      child: GestureDetector(
        onTapUp: (d) async {
          final box = context.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero);
          final result = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              offset.dx,
              offset.dy + box.size.height,
              offset.dx + 1,
              offset.dy + box.size.height + 1,
            ),
            color: AppColors.bg800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              side: const BorderSide(color: AppColors.border700),
            ),
            items: options.map((opt) {
              final isActive = sortOrder == opt.$1;
              return PopupMenuItem<String>(
                value: opt.$1,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(children: [
                  SizedBox(
                    width: 14,
                    child: isActive
                        ? const Icon(Icons.check,
                            size: 12, color: AppColors.accent400)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(opt.$2, style: AppTypography.body.copyWith(
                    color: isActive ? AppColors.accent400 : null,
                  )),
                ]),
              );
            }).toList(),
          );
          if (result != null) onChanged(result);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(
              sortOrder == 'newest' ? Icons.sort : Icons.sort_rounded,
              size: 14,
              color: sortOrder == 'newest'
                  ? AppColors.text500
                  : AppColors.accent400,
            ),
          ),
        ),
      ),
    );
  }
}
