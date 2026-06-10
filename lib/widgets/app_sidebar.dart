import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../services/cli_update_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_badge.dart';

/// Sidebar: agent CLI list (top) + task panel (bottom), separated by a
/// draggable horizontal divider — both sections resize elastically and the
/// chosen split is persisted.
///
/// Agents are multi-selectable: the selected set filters the task panel,
/// and an empty selection means "all agents".
class AppSidebar extends StatefulWidget {
  final List<AgentCli> agents;
  final Set<String> selectedAgentIds;
  final ValueChanged<String> onToggleAgent;
  final VoidCallback onRescan;
  final bool isScanning;
  /// When the last CLI detection completed — shown as a tooltip on the rescan
  /// button so users can tell how fresh the detection results are.
  final DateTime? lastScanTime;
  final Widget? taskPanel;
  final VoidCallback? onOpenSettings;
  /// Opens the session statistics dialog.
  final VoidCallback? onShowStats;
  /// Opens the "Add Custom Agent" dialog; hides the + button when null.
  final VoidCallback? onAddAgent;
  /// Remove a user-added custom agent (only offered for custom ids).
  final ValueChanged<AgentCli>? onRemoveAgent;
  /// Hide a built-in agent from the sidebar (offered for non-custom ids).
  final ValueChanged<AgentCli>? onHideAgent;
  /// How many agents are currently hidden — drives the "show hidden" footer.
  final int hiddenAgentCount;
  /// Restore all hidden agents to the sidebar.
  final VoidCallback? onShowHiddenAgents;
  /// Number of running terminals per agent id — drives the live session badge.
  final Map<String, int> sessionCounts;

  /// Latest version available per agent id — shows update badge when newer
  /// than the installed version.
  final Map<String, String> updateVersions;

  /// Opens the cluster event log dialog.
  final VoidCallback? onOpenEventLog;

  /// Number of error events in the event log — shown as a badge on the log icon.
  final int eventLogErrorCount;

  const AppSidebar({
    super.key,
    required this.agents,
    required this.selectedAgentIds,
    required this.onToggleAgent,
    required this.onRescan,
    this.isScanning = false,
    this.lastScanTime,
    this.taskPanel,
    this.onOpenSettings,
    this.onShowStats,
    this.onAddAgent,
    this.onRemoveAgent,
    this.onHideAgent,
    this.hiddenAgentCount = 0,
    this.onShowHiddenAgents,
    this.sessionCounts = const {},
    this.updateVersions = const {},
    this.onOpenEventLog,
    this.eventLogErrorCount = 0,
  });

  /// Vertical resize bounds for the agent section.
  static const double minAgentSectionHeight = 96;
  static const double minTaskSectionHeight = 160;
  static const double defaultAgentSectionHeight = 240;

  /// Key for the horizontal divider drag handle (used by widget tests).
  static const Key splitterKey = Key('sidebar_splitter');

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  late double _agentSectionHeight;
  bool _dragging = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _agentSectionHeight = SettingsService.agentSectionHeight ??
        AppSidebar.defaultAgentSectionHeight;
  }

  double _clamp(double height, double available) {
    final maxTop = available - AppSidebar.minTaskSectionHeight;
    if (maxTop <= AppSidebar.minAgentSectionHeight) {
      return AppSidebar.minAgentSectionHeight;
    }
    return height.clamp(AppSidebar.minAgentSectionHeight, maxTop);
  }

  void _onDragEnd() {
    setState(() => _dragging = false);
    SettingsService.setAgentSectionHeight(_agentSectionHeight);
  }

  @override
  Widget build(BuildContext context) {
    // Width is controlled by the parent (AppLayout's resizable split).
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface900_50,
        border: Border(
          right: BorderSide(color: AppColors.border800),
        ),
      ),
      child: Column(
        children: [
          // --- Logo / header ---
          SizedBox(
            height: AppSpacing.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.monitor,
                    size: AppSpacing.iconLg,
                    color: AppColors.accent400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.agentOSCli,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text100,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

          // --- Agents + tasks split ---
          Expanded(
            child: widget.taskPanel == null
                ? _agentSection(expanded: true)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final top =
                          _clamp(_agentSectionHeight, constraints.maxHeight);
                      return Column(
                        children: [
                          SizedBox(
                            height: top,
                            child: _agentSection(expanded: false),
                          ),

                          // Drag handle — straddles the divider line.
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeRow,
                            onEnter: (_) =>
                                setState(() => _hovering = true),
                            onExit: (_) =>
                                setState(() => _hovering = false),
                            child: GestureDetector(
                              key: AppSidebar.splitterKey,
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragStart: (_) =>
                                  setState(() => _dragging = true),
                              onVerticalDragUpdate: (d) => setState(() {
                                _agentSectionHeight = _clamp(
                                  _agentSectionHeight + d.delta.dy,
                                  constraints.maxHeight,
                                );
                              }),
                              onVerticalDragEnd: (_) => _onDragEnd(),
                              onVerticalDragCancel: _onDragEnd,
                              child: AnimatedContainer(
                                duration: AppSpacing.fastTransition,
                                height: 6,
                                color: _dragging
                                    ? AppColors.accent30
                                    : _hovering
                                        ? AppColors.accent10
                                        : Colors.transparent,
                                child: const Center(
                                  child: Divider(height: 1),
                                ),
                              ),
                            ),
                          ),

                          Expanded(child: widget.taskPanel!),
                        ],
                      );
                    },
                  ),
          ),

          // --- Footer ---
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.daemonActive,
                    style: AppTypography.meta,
                  ),
                ),
                if (widget.onOpenEventLog != null)
                  Tooltip(
                    message: 'Event Log (⇧⌘L)',
                    child: GestureDetector(
                      onTap: widget.onOpenEventLog,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.timeline_outlined,
                                size: 16,
                                color: widget.eventLogErrorCount > 0
                                    ? AppColors.red400
                                    : AppColors.text500,
                              ),
                              if (widget.eventLogErrorCount > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.red400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.onShowStats != null)
                  Tooltip(
                    message: AppLocalizations.of(context)!.statsTitle,
                    child: GestureDetector(
                      onTap: widget.onShowStats,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.bar_chart_outlined,
                            size: 16,
                            color: AppColors.text500,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.onOpenSettings != null)
                  GestureDetector(
                    onTap: widget.onOpenSettings,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.settings_outlined,
                          size: 16,
                          color: AppColors.text500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _agentSection({required bool expanded}) {
    final list = ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: widget.agents.length,
      itemBuilder: (context, index) {
        final agent = widget.agents[index];
        final isCustom = agent.id.startsWith('custom_');
        return _SidebarItem(
          agent: agent,
          isSelected: widget.selectedAgentIds.contains(agent.id),
          runningCount: widget.sessionCounts[agent.id] ?? 0,
          latestVersion: widget.updateVersions[agent.id],
          onTap: () => widget.onToggleAgent(agent.id),
          onMissingTap: agent.detected
              ? null
              : () => _showInstallDialog(context, agent),
          onRemove: isCustom && widget.onRemoveAgent != null
              ? () => widget.onRemoveAgent!(agent)
              : null,
          onHide: !isCustom && widget.onHideAgent != null
              ? () => widget.onHideAgent!(agent)
              : null,
        );
      },
    );

    return Column(
      children: [
        // --- Section header ---
        Padding(
          padding:
              const EdgeInsets.fromLTRB(12, 12, 12, AppSpacing.sectionGap),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible + ellipsis: the sidebar is resizable down to
              // 200px, so the header must tolerate narrow widths.
              Flexible(
                child: Text(
                  AppLocalizations.of(context)!.localEnvironments,
                  style: AppTypography.sectionHeader,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onAddAgent != null)
                    Tooltip(
                      message: AppLocalizations.of(context)!.addCustomAgent,
                      child: GestureDetector(
                        onTap: widget.onAddAgent,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(
                              Icons.add,
                              size: 15,
                              color: AppColors.text500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Tooltip(
                    message: widget.isScanning
                        ? AppLocalizations.of(context)!.scanning
                        : _lastScanLabel(context, widget.lastScanTime),
                    waitDuration: const Duration(milliseconds: 400),
                    child: GestureDetector(
                      onTap: widget.onRescan,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedRotation(
                          turns: widget.isScanning ? 1 : 0,
                          duration: const Duration(seconds: 1),
                          child: Icon(
                            Icons.refresh,
                            size: 14,
                            color: widget.isScanning
                                ? AppColors.accent400
                                : AppColors.text500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: list),
        if (widget.hiddenAgentCount > 0 && widget.onShowHiddenAgents != null)
          _HiddenAgentsFooter(
            count: widget.hiddenAgentCount,
            onShow: widget.onShowHiddenAgents!,
          ),
      ],
    );
  }
}

/// Footer row shown under the agent list when one or more agents are hidden,
/// offering a one-tap restore.
class _HiddenAgentsFooter extends StatelessWidget {
  final int count;
  final VoidCallback onShow;

  const _HiddenAgentsFooter({required this.count, required this.onShow});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onShow,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: [
              const Icon(Icons.visibility_off_outlined,
                  size: 12, color: AppColors.text500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.hiddenAgentsCount(count),
                  style: AppTypography.meta.copyWith(color: AppColors.text500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.showAllAgents,
                style: AppTypography.meta.copyWith(color: AppColors.accent400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns a human-readable "last scanned X ago" string for the rescan tooltip.
String _lastScanLabel(BuildContext context, DateTime? lastScanTime) {
  final l10n = AppLocalizations.of(context)!;
  if (lastScanTime == null) return l10n.rescanAgents;
  final diff = DateTime.now().difference(lastScanTime);
  if (diff.inSeconds < 60) return l10n.lastScannedJustNow;
  if (diff.inMinutes < 60) return l10n.lastScannedMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.lastScannedHoursAgo(diff.inHours);
  return l10n.lastScannedDaysAgo(diff.inDays);
}

void _showInstallDialog(BuildContext context, AgentCli agent) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bg800,
      title: Row(children: [
        const Icon(Icons.download_outlined,
            size: 18, color: AppColors.accent400),
        const SizedBox(width: 8),
        Text(l10n.installAgentTitle(agent.displayName),
            style: AppTypography.cardTitle),
      ]),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.agentNotFound(agent.displayName),
              style: AppTypography.body),
          if (agent.installHint != null) ...[
            const SizedBox(height: 12),
            Text(l10n.installWith,
                style: AppTypography.label),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg950,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border700),
              ),
              child: SelectableText(
                agent.installHint!,
                style: AppTypography.mono.copyWith(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(l10n.afterInstallRescan,
              style: AppTypography.meta),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style:
              TextButton.styleFrom(foregroundColor: AppColors.text400),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

/// Individual sidebar item — multi-select checkbox-style agent button.
class _SidebarItem extends StatefulWidget {
  final AgentCli agent;
  final bool isSelected;
  /// Number of running terminal sessions for this agent (0 = no badge).
  final int runningCount;
  /// Latest version from registry — shows update badge when newer than installed.
  final String? latestVersion;
  final VoidCallback onTap;
  final VoidCallback? onMissingTap;
  /// Non-null for user-added custom agents — "Remove" in the right-click menu.
  final VoidCallback? onRemove;
  /// Non-null for built-in agents — "Hide" in the right-click menu.
  final VoidCallback? onHide;

  const _SidebarItem({
    required this.agent,
    required this.isSelected,
    this.runningCount = 0,
    this.latestVersion,
    required this.onTap,
    this.onMissingTap,
    this.onRemove,
    this.onHide,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  Color get _bgColor {
    if (widget.isSelected) return AppColors.accent10;
    if (_isHovered) return AppColors.bg800;
    return Colors.transparent;
  }

  Future<void> _showRemoveMenu(BuildContext context, Offset pos) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppColors.bg800,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          side: const BorderSide(color: AppColors.border700)),
      items: [
        if (widget.onHide != null)
          PopupMenuItem<String>(
            value: 'hide',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.visibility_off_outlined,
                  size: 13, color: AppColors.text400),
              const SizedBox(width: 8),
              Text(l10n.hideAgent,
                  style:
                      AppTypography.body.copyWith(color: AppColors.text200)),
            ]),
          ),
        if (widget.onRemove != null)
          PopupMenuItem<String>(
            value: 'remove',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.delete_outline,
                  size: 13, color: AppColors.red400),
              const SizedBox(width: 8),
              Text(l10n.removeCustomAgent,
                  style:
                      AppTypography.body.copyWith(color: AppColors.red400)),
            ]),
          ),
      ],
    );
    if (result == 'remove') widget.onRemove?.call();
    if (result == 'hide') widget.onHide?.call();
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final isSelected = widget.isSelected;
    final textStyle = AppTypography.sidebarItem(selected: isSelected);
    final iconColor = isSelected
        ? AppColors.accent400
        : (_isHovered ? AppColors.text200 : AppColors.text500);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.agent.detected
            ? widget.onTap
            : (widget.onMissingTap ?? widget.onTap),
        onSecondaryTapUp: (widget.onRemove == null && widget.onHide == null)
            ? null
            : (d) => _showRemoveMenu(context, d.globalPosition),
        child: AnimatedContainer(
          duration: AppSpacing.normalTransition,
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: AppSpacing.itemGap),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sidebarItemPaddingH,
            vertical: AppSpacing.sidebarItemPaddingV,
          ),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.sidebarItemRadius),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.terminal,
                size: AppSpacing.iconMd,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  agent.displayName,
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Running session count badge — shows when ≥1 terminal is active.
              if (widget.runningCount > 0) ...[
                const SizedBox(width: 4),
                AppBadge.success('${widget.runningCount}'),
                const SizedBox(width: 4),
              ],
              // Update available badge — shows when registry has a newer version.
              if (widget.latestVersion != null &&
                  agent.version != null &&
                  CliUpdateService.isNewer(
                      agent.version!, widget.latestVersion!)) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: '↑ ${widget.latestVersion}  •  '
                      '${CliUpdateService.updateCommand(agent)}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: AppBadge(
                    label: '↑ ${widget.latestVersion}',
                    textColor: AppColors.labelYellow,
                    backgroundColor: AppColors.labelYellow.withAlpha(25),
                    borderColor: AppColors.labelYellow.withAlpha(60),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (agent.detected && agent.version != null)
                AppBadge.accent(agent.version!)
              else if (agent.detected)
                AppBadge.neutral(AppLocalizations.of(context)!.agentFound,
                    icon: Icons.check_circle)
              else
                AppBadge(
                    label: AppLocalizations.of(context)!.missing,
                    textColor: AppColors.red400,
                    backgroundColor: AppColors.red500_10,
                    borderColor: AppColors.red500_10),
            ],
          ),
        ),
      ),
    );
  }
}
