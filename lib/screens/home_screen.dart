import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../models/cli_registry.dart';
import '../models/pipeline_rule.dart';
import '../models/session_template.dart';
import '../services/cli_cache_service.dart';
import '../services/cli_detector.dart';
import '../services/cli_update_service.dart';
import '../services/custom_cli_service.dart';
import '../services/event_log_service.dart';
import '../services/export_service.dart';
import '../services/helpers_script_service.dart';
import '../services/ipc_server.dart';
import '../services/pipeline_rule_service.dart';
import '../services/project_memory_service.dart';
import '../services/session_manager.dart';
import '../services/session_template_service.dart';
import '../services/settings_service.dart';
import '../services/terminal_sessions_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/ansi_utils.dart';
import '../widgets/add_agent_dialog.dart';
import '../widgets/broadcast_dialog.dart';
import '../widgets/app_layout.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/live_agent_dashboard.dart';
import '../widgets/pipeline_rules_dialog.dart';
import '../widgets/template_manager_dialog.dart';
import '../widgets/task_panel.dart';
import '../widgets/command_palette.dart';
import '../widgets/keyboard_shortcuts_dialog.dart';
import '../widgets/session_stats_dialog.dart';
import '../widgets/event_log_panel.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/skill_manager_dialog.dart';
import '../widgets/terminal_pane.dart';
import '../widgets/workflow_templates_dialog.dart';
import '../widgets/workflow_run_dialog.dart';
import '../models/workflow_definition.dart';
import '../services/workflow_engine.dart';
import 'new_session_dialog.dart';

/// Single-page workspace: agent list (sidebar top) + task panel (sidebar
/// bottom) + embedded multi-tab terminal pane (right). No deep navigation —
/// every task terminal opens, runs and switches in place.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AgentCli> _clis = [];

  /// Multi-selected agents — filters the task panel; empty = all agents.
  /// [_primaryAgentId] (the most recent selection) is the target for
  /// "New Task".
  final Set<String> _selectedAgentIds = {};
  String? _primaryAgentId;

  /// Built-in CLIs the user hid from the sidebar (custom CLIs are removed
  /// outright). Persisted via [SettingsService.hiddenAgentIds].
  Set<String> _hiddenAgentIds = {};

  bool _isScanning = false;
  DateTime? _lastScanTime;
  Set<int> _pinnedIds = {};
  final TextEditingController _searchController = TextEditingController();
  late final SessionManager _sessionManager;
  late final TerminalSessionsController _terminals;
  late final bool Function(KeyEvent) _keyHandler;

  /// Maps session id → target AgentCli to auto-relay to on successful exit.
  final Map<int, AgentCli> _autoRelayMap = {};

  /// Latest versions from npm/PyPI registries — keyed by CLI id.
  Map<String, String> _updateVersions = {};
  StreamSubscription<({int sessionId, int exitCode})>? _exitSub;

  final _ipcServer = IpcServer();
  StreamSubscription<IpcEvent>? _ipcSub;

  List<SessionTemplate> _templates = [];
  List<PipelineRule> _pipelineRules = [];

  /// Watchdog retry counter — maps original session ID to retry attempt number.
  /// Cleared when the session eventually succeeds or exhausts retries.
  final Map<int, int> _retryCount = {};

  final _eventLog = EventLogService();
  late final WorkflowEngine _workflowEngine;

  @override
  void initState() {
    super.initState();
    final db = context.read<AppDatabase>();
    _sessionManager = SessionManager(db);
    _terminals = TerminalSessionsController(_sessionManager);
    _workflowEngine = WorkflowEngine(db, _sessionManager, _terminals, _eventLog);
    _terminals.onMemorySynced = (sessionName, agentName) {
      _eventLog.log(
        ClusterEventKind.memorySync,
        sessionName: sessionName,
        detail: agentName,
      );
    };
    _pinnedIds = SettingsService.pinnedSessionIds;
    _hiddenAgentIds = SettingsService.hiddenAgentIds;
    _startIpcServer();
    _loadInitialData();
    _keyHandler = (event) {
      if (event is! KeyDownEvent) return false;
      if (!HardwareKeyboard.instance.isMetaPressed) return false;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyK:
          _openCommandPalette();
          return true;
        case LogicalKeyboardKey.comma:
          _openSettings();
          return true;
        case LogicalKeyboardKey.slash:
          _showKeyboardShortcuts();
          return true;
        case LogicalKeyboardKey.keyN:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _openNewSessionFromClipboard();
          } else {
            _openNewSession();
          }
          return true;
        case LogicalKeyboardKey.keyB:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _broadcastToRunningAgents();
            return true;
          }
          return false;
        case LogicalKeyboardKey.keyI:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _injectToActiveAgent();
            return true;
          }
          return false;
        case LogicalKeyboardKey.keyE:
          _exportActiveTerminal();
          return true;
        case LogicalKeyboardKey.keyG:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _openPipelineRules();
            return true;
          }
          return false;
        case LogicalKeyboardKey.keyD:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _openLiveDashboard();
            return true;
          }
          return false;
        case LogicalKeyboardKey.keyL:
          if (HardwareKeyboard.instance.isShiftPressed) {
            EventLogPanel.show(context, logService: _eventLog);
            return true;
          }
          return false;
        case LogicalKeyboardKey.keyK:
          if (HardwareKeyboard.instance.isShiftPressed) {
            _openSkills();
            return true;
          }
          return false;
        case LogicalKeyboardKey.keyW:
          final id = _terminals.activeId;
          if (id != null) _closeTerminalWithConfirm(id);
          return true;
        case LogicalKeyboardKey.bracketRight: // Cmd+] — next tab
          _switchTab(1);
          return true;
        case LogicalKeyboardKey.bracketLeft: // Cmd+[ — previous tab
          _switchTab(-1);
          return true;
        // Cmd+1 … Cmd+9 — jump to terminal tab by position
        case LogicalKeyboardKey.digit1:
        case LogicalKeyboardKey.digit2:
        case LogicalKeyboardKey.digit3:
        case LogicalKeyboardKey.digit4:
        case LogicalKeyboardKey.digit5:
        case LogicalKeyboardKey.digit6:
        case LogicalKeyboardKey.digit7:
        case LogicalKeyboardKey.digit8:
        case LogicalKeyboardKey.digit9:
          final n = int.tryParse(event.logicalKey.keyLabel);
          if (n != null) {
            final tabs = _terminals.openTerminals;
            final idx = n - 1;
            if (idx < tabs.length) {
              _terminals.setActive(tabs[idx].sessionId);
            }
          }
          return true;
        default:
          return false;
      }
    };
    HardwareKeyboard.instance.addHandler(_keyHandler);
    _terminals.addListener(_updateDockBadge);
    _exitSub = _terminals.exitEvents.listen(_onSessionExited);
  }

  void _updateDockBadge() {
    // Dock badge update — requires window_manager (removed to fix Patrol
    // "Running Background" activation issue on macOS 26). No-op for now.
  }

  @override
  void dispose() {
    _ipcSub?.cancel();
    _ipcServer.stop();
    _exitSub?.cancel();
    _terminals.removeListener(_updateDockBadge);
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    _searchController.dispose();
    _terminals.dispose();
    _workflowEngine.dispose();
    _eventLog.dispose();
    super.dispose();
  }

  Future<void> _startIpcServer() async {
    try {
      await _ipcServer.start();
      _terminals.ipcPort = _ipcServer.port;
      _ipcSub = _ipcServer.events.listen(_onIpcEvent);
      unawaited(HelpersScriptService.write());
      _terminals.helpersScriptPath = HelpersScriptService.path;

      _ipcServer.onGetSessions = () => _terminals.openTerminals
          .map((t) => IpcSessionInfo(
                id: t.sessionId,
                name: t.sessionName,
                agentId: t.cli.id,
                status: t.effectiveStatus,
                workingDirectory: t.workingDirectory,
              ))
          .toList();

      _ipcServer.onInject = (sessionId, text) async {
        final term = _terminals.terminalOf(sessionId);
        if (term?.pty == null) return false;
        term!.pty!.write(const Utf8Encoder().convert('$text\n'));
        return true;
      };

      _ipcServer.onGetOutput = (sessionId, maxLines) {
        final term = _terminals.terminalOf(sessionId);
        if (term == null) return null;
        final raw = term.peekOutput(maxLines: maxLines);
        if (raw.isEmpty) return [];
        return raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      };

      _ipcServer.onSubscribeOutput =
          (sessionId) => _terminals.outputStreamOf(sessionId);
    } catch (_) {
      // IPC server is non-critical — PTYs work fine without it.
    }
  }

  Future<void> _onIpcEvent(IpcEvent event) async {
    switch (event.type) {
      case IpcEventType.stop:
      case IpcEventType.result:
        // Treat an IPC stop/result as a successful exit trigger for auto-relay.
        // This fires when a Claude Code Stop hook POSTs back to us.
        final targetCli = _autoRelayMap[event.sessionId];
        final session = await _sessionManager.getSession(event.sessionId);
        final sName = session?.name ?? '#${event.sessionId}';
        _eventLog.log(
          event.type == IpcEventType.result
              ? ClusterEventKind.ipcResult
              : ClusterEventKind.ipcStop,
          sessionName: sName,
        );
        if (targetCli == null) {
          _showIpcToast(event);
          break;
        }
        if (session != null && mounted) {
          _showIpcToast(event, sessionName: session.name);
          await _autoDispatchTo(session, targetCli);
        }
      case IpcEventType.notify:
        final notifySession =
            await _sessionManager.getSession(event.sessionId);
        final notifyMsg = event.data['message'] ?? event.data['text'];
        _eventLog.log(
          ClusterEventKind.ipcNotify,
          sessionName: notifySession?.name ?? '#${event.sessionId}',
          detail: notifyMsg is String && notifyMsg.isNotEmpty ? notifyMsg : null,
        );
        _showIpcToast(event);
      case IpcEventType.unknown:
        break;
    }
  }

  void _showIpcToast(IpcEvent event, {String? sessionName}) {
    if (!mounted) return;
    final label = switch (event.type) {
      IpcEventType.stop => 'stop',
      IpcEventType.result => 'result',
      IpcEventType.notify => 'notify',
      IpcEventType.unknown => 'event',
    };
    final name = sessionName ?? '#${event.sessionId}';
    // For notify events, surface the data payload if it contains a readable message.
    String? dataMessage;
    if (event.type == IpcEventType.notify) {
      final msg = event.data['message'] ?? event.data['text'];
      if (msg is String && msg.isNotEmpty) dataMessage = msg;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 14, color: AppColors.accent400),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IPC [$label] from $name',
                    style: AppTypography.body.copyWith(color: AppColors.text100),
                  ),
                  if (dataMessage != null)
                    Text(
                      dataMessage,
                      style: AppTypography.mono.copyWith(
                          fontSize: 11, color: AppColors.text400),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.bg800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border700),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    _lastScanTime = SettingsService.lastDetectionTime;
    // Load templates and pipeline rules alongside CLI cache for instant display
    SessionTemplateService.load()
        .then((t) { if (mounted) setState(() => _templates = t); });
    PipelineRuleService.load()
        .then((r) { if (mounted) setState(() => _pipelineRules = r); });
    // Load cached results for instant display
    final cached = await CliCacheService.load();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _clis = cached;
        _primaryAgentId = cached.first.id;
      });
    } else {
      setState(() {
        _clis = CliRegistry.createAll();
      });
    }
    // Auto-start detection in background
    _startDetection();
  }

  Future<void> _startDetection() async {
    if (_isScanning) return; // prevent concurrent scans
    // Re-resolve the login-shell PATH on every manual rescan so a CLI just
    // installed into a new directory is picked up without restarting the app.
    CliDetector.clearPathCache();
    // Snapshot previously-detected state for the post-scan diff snackbar.
    final previousDetected = {for (final c in _clis) c.id: c.detected};
    // Built-in registry + user-added custom agents share one detection flow.
    final custom = await CustomCliService.load();
    final registry = [...CliRegistry.createAll(), ...custom];
    setState(() {
      _isScanning = true;
      _clis = registry;
    });
    final results = await CliDetector.detectAll(
      registry,
      onUpdate: (result) {
        // Progressive: paint each CLI the moment it resolves — don't wait for
        // all 12 to finish before showing detection results.
        if (!mounted) return;
        setState(() {
          _clis = [
            for (final c in _clis)
              c.id == result.id ? result : c,
          ];
        });
      },
    );
    await CliCacheService.save(results);
    await SettingsService.setLastDetectionTime(DateTime.now());
    if (!mounted) return;
    setState(() {
      _clis = results;
      _isScanning = false;
      _lastScanTime = DateTime.now();
      _primaryAgentId ??= results.isNotEmpty ? results.first.id : null;
    });
    _showDetectionDiff(previousDetected, results);
    // Fire-and-forget version check — updates the update badge asynchronously.
    _checkForUpdates(results);
  }

  Future<void> _checkForUpdates(List<AgentCli> clis) async {
    final versions = await CliUpdateService.checkAll(clis);
    if (!mounted || versions.isEmpty) return;
    setState(() => _updateVersions = versions);
  }

  void _showDetectionDiff(
    Map<String, bool> previousDetected,
    List<AgentCli> after,
  ) {
    final newlyFound = after
        .where((c) => c.detected && previousDetected[c.id] == false)
        .toList();
    final nowMissing = after
        .where((c) => !c.detected && previousDetected[c.id] == true)
        .toList();
    if (newlyFound.isEmpty && nowMissing.isEmpty) return;

    final parts = <String>[];
    if (newlyFound.isNotEmpty) {
      parts.add('Found: ${newlyFound.map((c) => c.displayName).join(', ')}');
    }
    if (nowMissing.isNotEmpty) {
      parts.add('Missing: ${nowMissing.map((c) => c.displayName).join(', ')}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          parts.join(' · '),
          style: AppTypography.body.copyWith(color: AppColors.text100),
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.bg800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border700),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openAddAgent() async {
    await AddAgentDialog.show(
      context,
      onAdded: (_) => _startDetection(),
    );
  }

  Future<void> _removeCustomAgent(AgentCli agent) async {
    await CustomCliService.remove(agent.id);
    setState(() {
      _clis = _clis.where((c) => c.id != agent.id).toList();
      _selectedAgentIds.remove(agent.id);
      if (_primaryAgentId == agent.id) _primaryAgentId = null;
    });
    await CliCacheService.save(_clis);
  }

  /// Agents shown in the sidebar — the full list minus any the user hid.
  List<AgentCli> get _visibleClis =>
      _clis.where((c) => !_hiddenAgentIds.contains(c.id)).toList();

  /// Hide a built-in CLI from the sidebar (custom CLIs use [_removeCustomAgent]).
  Future<void> _hideAgent(AgentCli agent) async {
    setState(() {
      _hiddenAgentIds = {..._hiddenAgentIds, agent.id};
      _selectedAgentIds.remove(agent.id);
      if (_primaryAgentId == agent.id) _primaryAgentId = null;
    });
    await SettingsService.setHiddenAgentIds(_hiddenAgentIds);
  }

  /// Restore all hidden CLIs to the sidebar.
  Future<void> _unhideAllAgents() async {
    setState(() => _hiddenAgentIds = {});
    await SettingsService.setHiddenAgentIds(_hiddenAgentIds);
  }

  void _toggleAgent(String id) {
    setState(() {
      if (_selectedAgentIds.contains(id)) {
        _selectedAgentIds.remove(id);
        if (_primaryAgentId == id && _selectedAgentIds.isNotEmpty) {
          _primaryAgentId = _selectedAgentIds.last;
        }
      } else {
        _selectedAgentIds.add(id);
        _primaryAgentId = id;
      }
    });
  }

  /// Agent used for "New Task" — the most recently selected one, falling
  /// back to the first detected CLI.
  AgentCli? get _primaryAgent {
    if (_clis.isEmpty) return null;
    if (_primaryAgentId == null) return _clis.first;
    return _clis.firstWhere(
      (c) => c.id == _primaryAgentId,
      orElse: () => _clis.first,
    );
  }

  AgentCli? _agentFor(String cliId) {
    if (_clis.isEmpty) return null;
    return _clis.firstWhere((c) => c.id == cliId, orElse: () => _clis.first);
  }

  String _agentNameOf(String cliId) =>
      _agentFor(cliId)?.displayName ?? cliId;

  void _openNewSession() {
    if (_clis.isEmpty) return;
    // Multi-dispatch: use all selected agents, or fall back to primary.
    final targets = _selectedAgentIds.isEmpty
        ? [_primaryAgent].whereType<AgentCli>().toList()
        : _clis
            .where((c) => _selectedAgentIds.contains(c.id))
            .toList();
    if (targets.isEmpty) return;
    NewSessionDialog.show(
      context,
      clis: targets,
      sessionManager: _sessionManager,
      onCreated: (session) => _openTerminal(session),
      onSaveTemplate: _saveTemplate,
    );
  }

  void _runOnAllDetectedAgents() {
    final detected = _clis.where((c) => c.detected).toList();
    if (detected.length < 2) return;
    NewSessionDialog.show(
      context,
      clis: detected,
      sessionManager: _sessionManager,
      onCreated: (session) => _openTerminal(session),
      onSaveTemplate: _saveTemplate,
    );
  }

  void _openTerminal(TaskSession session) {
    final agent = _agentFor(session.agentCliId);
    if (agent == null) return;
    _eventLog.log(
      ClusterEventKind.sessionStarted,
      sessionName: session.name,
    );
    unawaited(_openTerminalAsync(session, agent));
  }

  Future<void> _openTerminalAsync(TaskSession session, AgentCli agent) async {
    final wd = session.workingDirectory;
    if (wd != null && wd.isNotEmpty) {
      final synced = await ProjectMemoryService.syncForCli(
        workingDirectory: wd,
        cliId: agent.id,
      );
      if (synced && mounted) {
        _eventLog.log(
          ClusterEventKind.memorySync,
          sessionName: session.name,
          detail: agent.displayName,
        );
      }
    }
    await _terminals.open(session, agent);
  }

  Future<void> _renameSession(TaskSession session, String newName) async {
    await _sessionManager.renameSession(session.id, newName);
  }

  Future<void> _updateSessionNotes(int id, String? notes) async {
    await context.read<AppDatabase>().updateSessionNotes(id, notes);
  }

  Future<void> _updateSessionColorLabel(int id, String? colorLabel) async {
    await context.read<AppDatabase>().updateSessionColorLabel(id, colorLabel);
  }

  Future<void> _closeTerminalWithConfirm(int sessionId) async {
    final term = _terminals.openTerminals
        .where((t) => t.sessionId == sessionId)
        .firstOrNull;
    if (term == null) return;
    if (term.running) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bg800,
          title: Text(AppLocalizations.of(context)!.deleteSession,
              style: AppTypography.cardTitle),
          content: Text(
              AppLocalizations.of(context)!.taskStillRunningStop,
              style: AppTypography.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.text400),
              child: Text(AppLocalizations.of(context)!.keepRunning),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.red400),
              child: Text(AppLocalizations.of(context)!.stopAndClose),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _terminals.close(sessionId);
  }

  Future<void> _openNewSessionFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    final agent = _primaryAgent;
    if (agent == null) return;
    final targets = _selectedAgentIds.isEmpty
        ? [agent]
        : _clis.where((c) => _selectedAgentIds.contains(c.id)).toList();
    if (targets.isEmpty) return;
    NewSessionDialog.show(
      context,
      clis: targets,
      sessionManager: _sessionManager,
      onCreated: (session) => _openTerminal(session),
      initialPrompt: text,
    );
  }

  void _openFollowUp(ActiveTerminal term) {
    final agent = _agentFor(term.cli.id) ?? term.cli;
    NewSessionDialog.show(
      context,
      clis: [agent],
      sessionManager: _sessionManager,
      onCreated: (session) => _openTerminal(session),
    );
  }

  void _showKeyboardShortcuts() {
    KeyboardShortcutsDialog.show(context);
  }

  void _showStats() {
    SessionStatsDialog.show(context, agents: _clis);
  }

  Future<void> _exportActiveTerminal() async {
    final activeId = _terminals.activeId;
    if (activeId == null) return;
    final session = await _sessionManager.getSession(activeId);
    if (session == null || !mounted) return;
    final agent = _agentFor(session.agentCliId);
    final agentName = agent?.displayName ?? session.agentCliId;
    // Prefer live PTY output for running sessions.
    final liveOutput = _terminals.getOutputTail(activeId, maxLines: 100000);
    await ExportService.exportSession(
      context,
      session,
      agentName: agentName,
      liveOutput: liveOutput.isNotEmpty ? liveOutput : null,
    );
  }

  Future<void> _saveTemplate(
    String name,
    String agentId,
    String? workingDir,
    String prompt,
  ) async {
    final tmpl = await SessionTemplateService.create(
      name: name,
      agentId: agentId,
      workingDirectory: workingDir,
      prompt: prompt,
    );
    if (mounted) setState(() => _templates = [..._templates, tmpl]);
  }

  void _openTemplateManager() {
    TemplateManagerDialog.show(
      context,
      agents: _clis,
      onLaunch: _launchTemplate,
    ).then((_) async {
      // Reload templates in case user deleted some.
      final updated = await SessionTemplateService.load();
      if (mounted) setState(() => _templates = updated);
    });
  }

  void _openPipelineRules() {
    PipelineRulesDialog.show(context, agents: _clis).then((_) async {
      final updated = await PipelineRuleService.load();
      if (mounted) setState(() => _pipelineRules = updated);
    });
  }

  void _openWorkflowTemplates() {
    if (!mounted) return;
    WorkflowTemplatesDialog.show(
      context,
      agents: _clis,
      onLaunch: _launchWorkflow,
    );
  }

  /// Opens the skill manager, scoped to the active terminal's project dir (if
  /// any) so project-level skills can be managed alongside global ones.
  void _openSkills() {
    if (!mounted) return;
    SkillManagerDialog.show(
      context,
      workingDirectory: _terminals.active?.workingDirectory,
    );
  }

  Future<void> _launchWorkflow(
    WorkflowDefinition definition,
    String? workingDirectory,
  ) async {
    if (!mounted) return;
    try {
      await _workflowEngine.start(
        definition,
        workingDirectory: workingDirectory,
        availableClis: _clis,
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierColor: AppColors.black60,
        barrierDismissible: false,
        builder: (_) => WorkflowRunDialog(
          engine: _workflowEngine,
          definition: definition,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workflow error: $e',
              style: AppTypography.body.copyWith(color: AppColors.text100)),
          backgroundColor: AppColors.bg800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openLiveDashboard() {
    if (!mounted) return;
    LiveAgentDashboard.show(
      context,
      terminals: _terminals,
      onJumpTo: (sessionId) {
        _terminals.setActive(sessionId);
      },
      onInject: (sessionId, name) {
        BroadcastDialog.showForSession(context, _terminals, sessionId, name);
      },
    );
  }

  void _launchTemplate(SessionTemplate template) {
    final cli = _clis.firstWhere(
      (c) => c.id == template.agentId,
      orElse: () => _clis.firstWhere((c) => c.detected,
          orElse: () => _clis.first),
    );
    NewSessionDialog.show(
      context,
      clis: [cli],
      sessionManager: _sessionManager,
      onCreated: (s) async {
        await _terminals.open(s, cli);
      },
      initialPrompt: template.prompt,
      initialWorkingDirectory: template.workingDirectory,
      onSaveTemplate: _saveTemplate,
    );
  }

  void _openCommandPalette() {
    _sessionManager.watchSessions().first.then((sessions) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        builder: (_) => CommandPalette(
          sessions: sessions,
          agents: _clis,
          onOpenSession: _openTerminal,
          onNewTask: _openNewSession,
          onRescan: _startDetection,
          onOpenSettings: _openSettings,
          onRunOnAllAgents: _runOnAllDetectedAgents,
          onBroadcast: _broadcastToRunningAgents,
          runningAgentCount: _terminals.runningTerminals.length,
          templates: _templates,
          onLaunchTemplate: _launchTemplate,
          onManageTemplates: _templates.isNotEmpty ? _openTemplateManager : null,
          onManagePipelineRules: _openPipelineRules,
          onOpenDashboard: _openLiveDashboard,
          onOpenEventLog: () =>
              EventLogPanel.show(context, logService: _eventLog),
          onOpenWorkflows: _openWorkflowTemplates,
          onOpenSkills: _openSkills,
        ),
      );
    });
  }

  void _openSettings() {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (_) => Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.28,
          heightFactor: 1.0,
          child: SettingsDrawer(
            onFontSizeChanged: (_) => setState(() {}),
            ipcPort: _ipcServer.port,
            agents: _clis,
            eventLogService: _eventLog,
          ),
        ),
      ),
    );
  }

  /// Switch to the next (+1) or previous (-1) terminal tab.
  void _switchTab(int delta) {
    final tabs = _terminals.openTerminals;
    if (tabs.length < 2) return;
    final current = tabs.indexWhere((t) => t.sessionId == _terminals.activeId);
    if (current == -1) return;
    final next = (current + delta) % tabs.length;
    _terminals.setActive(tabs[next].sessionId);
  }

  /// Open a new task dialog pre-filled with [source]'s working directory.
  /// Prefers the same agent type; falls back to any detected CLI.
  Future<void> _continueInProject(TaskSession source) async {
    final sameCli = _clis
        .where((c) => c.id == source.agentCliId && c.detected)
        .firstOrNull;
    final target = sameCli ??
        _clis.where((c) => c.detected).firstOrNull;
    if (target == null || !mounted) return;

    await NewSessionDialog.show(
      context,
      clis: [target],
      sessionManager: _sessionManager,
      onCreated: _openTerminal,
      initialWorkingDirectory: source.workingDirectory,
    );
  }

  Future<void> _injectToSession(TaskSession source) async {
    if (!mounted) return;
    await BroadcastDialog.showForSession(
      context,
      _terminals,
      source.id,
      source.name,
    );
  }

  void _broadcastToRunningAgents() {
    if (!mounted) return;
    if (_terminals.runningTerminals.isEmpty) return;
    BroadcastDialog.show(context, _terminals);
  }

  void _injectToActiveAgent() {
    if (!mounted) return;
    final active = _terminals.active;
    if (active == null || !active.running) return;
    BroadcastDialog.showForSession(
        context, _terminals, active.sessionId, active.sessionName);
  }

  Future<void> _cloneSession(TaskSession source) async {
    final agent = _agentFor(source.agentCliId) ??
        _clis.where((c) => c.detected).firstOrNull;
    if (agent == null || !mounted) return;
    await NewSessionDialog.show(
      context,
      clis: [agent],
      sessionManager: _sessionManager,
      onCreated: _openTerminal,
      initialPrompt: source.input?.trim(),
      initialWorkingDirectory: source.workingDirectory,
    );
  }

  Future<void> _dispatchSessionTo(TaskSession source, AgentCli cli) async {
    // If the source session captured output, build a context-rich prompt
    // for the receiving agent and let the user review/edit before dispatching.
    String? relayPrompt = source.input;
    if (source.output != null && source.output!.isNotEmpty) {
      final outputSnippet = AnsiUtils.tail(source.output!, maxChars: 3000);
      final buf = StringBuffer();
      buf.writeln('[Output from: ${source.name}]');
      buf.writeln();
      buf.writeln(outputSnippet);
      if (source.input != null && source.input!.isNotEmpty) {
        buf.writeln();
        buf.writeln('---');
        buf.writeln('Original task: ${source.input}');
      }
      relayPrompt = buf.toString().trim();
    }

    if (!mounted) return;
    await NewSessionDialog.show(
      context,
      clis: [cli],
      sessionManager: _sessionManager,
      onCreated: _openTerminal,
      initialPrompt: relayPrompt,
    );
  }

  Future<void> _dispatchSessionToAll(TaskSession source) async {
    final otherAgents = _clis
        .where((c) => c.id != source.agentCliId && c.detected)
        .toList();
    if (otherAgents.isEmpty || !mounted) return;

    String? relayPrompt = source.input;
    if (source.output != null && source.output!.isNotEmpty) {
      final outputSnippet = AnsiUtils.tail(source.output!, maxChars: 3000);
      final buf = StringBuffer();
      buf.writeln('[Output from: ${source.name}]');
      buf.writeln();
      buf.writeln(outputSnippet);
      if (source.input != null && source.input!.isNotEmpty) {
        buf.writeln();
        buf.writeln('---');
        buf.writeln('Original task: ${source.input}');
      }
      relayPrompt = buf.toString().trim();
    }

    await NewSessionDialog.show(
      context,
      clis: otherAgents,
      sessionManager: _sessionManager,
      onCreated: _openTerminal,
      initialPrompt: relayPrompt,
    );
  }

  /// Called when any PTY exits. Fires the auto-relay if one was configured.
  Future<void> _onSessionExited(
      ({int sessionId, int exitCode}) event) async {
    final targetCli = _autoRelayMap.remove(event.sessionId);
    if (mounted) setState(() {});
    final session = await _sessionManager.getSession(event.sessionId);
    if (session == null || !mounted) return;

    // If this session belongs to a workflow, let the engine handle it.
    if (session.workflowRunId != null && session.workflowRunId!.isNotEmpty) {
      return;
    }

    // Log session completion to the event log.
    final success = event.exitCode == 0;
    _eventLog.log(
      success
          ? ClusterEventKind.sessionCompleted
          : (event.exitCode == -1
              ? ClusterEventKind.sessionCancelled
              : ClusterEventKind.sessionFailed),
      sessionName: session.name,
      detail: success ? null : 'exit ${event.exitCode}',
    );

    // Per-session override takes priority.
    if (targetCli != null && event.exitCode == 0) {
      await _autoDispatchTo(session, targetCli);
      return;
    }

    // Fall back to persistent pipeline rules.
    final matchingRules = PipelineRuleService.rulesFor(
      _pipelineRules,
      session.agentCliId,
      success: success,
    );
    for (final rule in matchingRules) {
      final dest = _agentFor(rule.targetAgentId);
      if (dest != null && mounted) {
        _eventLog.log(
          ClusterEventKind.pipelineRelay,
          sessionName: session.name,
          detail: '→ ${dest.displayName}',
        );
        await _autoDispatchTo(session, dest);
      }
    }

    // Watchdog: auto-retry failed sessions if enabled.
    if (!success && SettingsService.watchdogEnabled) {
      await _maybeWatchdogRetry(session);
    } else if (success) {
      // Clear retry state on success.
      _retryCount.remove(event.sessionId);
    }
  }

  /// Auto-retry [session] if the watchdog policy allows it.
  Future<void> _maybeWatchdogRetry(TaskSession session) async {
    final minRun = SettingsService.watchdogMinRunSeconds;
    final ranFor = session.durationMs != null
        ? session.durationMs! ~/ 1000
        : 0;
    if (ranFor < minRun) return; // crashed too fast — don't retry

    final count = (_retryCount[session.id] ?? 0) + 1;
    if (count > SettingsService.watchdogMaxRetries) {
      _retryCount.remove(session.id);
      _eventLog.log(
        ClusterEventKind.watchdogExhausted,
        sessionName: session.name,
        detail: 'max ${SettingsService.watchdogMaxRetries} retries',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 14, color: AppColors.labelYellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Watchdog: "${session.name}" exhausted retries.',
                  style:
                      AppTypography.body.copyWith(color: AppColors.text100),
                ),
              ),
            ]),
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.bg800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border700),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    final agent = _agentFor(session.agentCliId);
    if (agent == null || !mounted) return;

    _retryCount[session.id] = count;

    // Brief delay before retry so the user can see what happened.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final newId = await _sessionManager.createSession(
      name: session.name,
      cli: agent,
      input: session.input,
      workingDirectory: session.workingDirectory,
      parentSessionId: session.id,
    );
    final retrySession = await _sessionManager.getSession(newId);
    if (retrySession != null && mounted) {
      _retryCount[retrySession.id] = count; // carry count to new session
      _eventLog.log(
        ClusterEventKind.watchdogRetry,
        sessionName: session.name,
        detail: 'attempt $count/${SettingsService.watchdogMaxRetries}',
      );
      _openTerminal(retrySession);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.refresh, size: 14, color: AppColors.accent400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Watchdog: retrying "${session.name}" ($count/${SettingsService.watchdogMaxRetries})',
                style:
                    AppTypography.body.copyWith(color: AppColors.text100),
              ),
            ),
          ]),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.bg800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border700),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Set (or clear when [cli] is null) an auto-relay target for a session.
  void _setAutoRelay(int sessionId, AgentCli? cli) {
    setState(() {
      if (cli == null) {
        _autoRelayMap.remove(sessionId);
      } else {
        _autoRelayMap[sessionId] = cli;
      }
    });
  }

  /// Create and immediately open a new session with the source's output as
  /// context — no dialog shown (auto-triggered on exit).
  Future<void> _autoDispatchTo(TaskSession source, AgentCli cli) async {
    String prompt = source.input ?? '';
    if (source.output != null && source.output!.isNotEmpty) {
      final outputSnippet = AnsiUtils.tail(source.output!, maxChars: 3000);
      final buf = StringBuffer()
        ..writeln('[Output from: ${source.name}]')
        ..writeln()
        ..writeln(outputSnippet);
      if (source.input != null && source.input!.isNotEmpty) {
        buf
          ..writeln()
          ..writeln('---')
          ..writeln('Original task: ${source.input}');
      }
      prompt = buf.toString().trim();
    }
    final id = await _sessionManager.createSession(
      name: '${source.name} → ${cli.displayName}',
      cli: cli,
      workingDirectory: source.workingDirectory,
      input: prompt,
      parentSessionId: source.id,
    );
    final session = await _sessionManager.getSession(id);
    if (session != null && mounted) await _terminals.open(session, cli);
  }

  Future<void> _clearFinishedSessions() async {
    await _sessionManager.clearFinishedSessions();
  }

  void _togglePin(int id) {
    final updated = Set<int>.from(_pinnedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    setState(() => _pinnedIds = updated);
    unawaited(SettingsService.setPinnedSessionIds(updated));
  }

  Future<void> _confirmDeleteSession(TaskSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg800,
        title: Text(l10n.deleteSession, style: AppTypography.cardTitle),
        content: Text(
          l10n.deleteSessionConfirm(session.name),
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red400),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _terminals.close(session.id);
      await _sessionManager.deleteSession(session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      constrainContent: false,
      sidebar: AnimatedBuilder(
        animation: Listenable.merge([_terminals, _eventLog]),
        builder: (context, _) {
          // Compute running terminal counts per agent for the sidebar badge.
          final counts = <String, int>{};
          for (final t in _terminals.openTerminals) {
            if (t.running) counts[t.cli.id] = (counts[t.cli.id] ?? 0) + 1;
          }
          return AppSidebar(
            agents: _visibleClis,
            selectedAgentIds: _selectedAgentIds,
            onToggleAgent: _toggleAgent,
            onRescan: _isScanning ? () {} : _startDetection,
            isScanning: _isScanning,
            lastScanTime: _lastScanTime,
            onOpenSettings: _openSettings,
            onShowStats: _showStats,
            onAddAgent: _openAddAgent,
            onRemoveAgent: _removeCustomAgent,
            onHideAgent: _hideAgent,
            hiddenAgentCount: _hiddenAgentIds.length,
            onShowHiddenAgents: _unhideAllAgents,
            sessionCounts: counts,
            updateVersions: _updateVersions,
            onOpenEventLog: () =>
                EventLogPanel.show(context, logService: _eventLog),
            eventLogErrorCount: _eventLog.errorCount,
            taskPanel: TaskPanel(
          sessionsStream: _sessionManager.watchSessions(),
          terminals: _terminals,
          searchQuery: _searchController.text,
          agents: _clis,
          selectedAgentIds: _selectedAgentIds,
          onToggleAgent: _toggleAgent,
          onClearAgents: () => setState(_selectedAgentIds.clear),
          agentNameOf: _agentNameOf,
          onOpen: _openTerminal,
          onDelete: _confirmDeleteSession,
          onRename: _renameSession,
          onDispatchTo: _dispatchSessionTo,
          onDispatchToAll: _dispatchSessionToAll,
          onClone: _cloneSession,
          onUpdateNotes: _updateSessionNotes,
          onUpdateColorLabel: _updateSessionColorLabel,
          onContinueHere: _continueInProject,
          onInjectMessage: _injectToSession,
          onClearFinished: _clearFinishedSessions,
          onNewTask: _openNewSession,
          pinnedIds: _pinnedIds,
          onTogglePin: _togglePin,
          chainTargetOf: (id) => _autoRelayMap[id],
          onChainTo: _setAutoRelay,
        ),
          );
        },
      ),
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: AppSearchBar(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                hintText: AppLocalizations.of(context)!.searchHint,
              ),
            ),
            AnimatedBuilder(
              animation: _terminals,
              builder: (context, _) {
                final running = _terminals.openTerminals
                    .where((t) => t.running)
                    .length;
                if (running == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Tooltip(
                    message: 'Live Dashboard (⇧⌘D)',
                    waitDuration: const Duration(milliseconds: 500),
                    child: GestureDetector(
                      onTap: _openLiveDashboard,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.emerald500.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.emerald500.withAlpha(77)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald500,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!
                                    .runningCount(running),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.emerald500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.grid_view_outlined,
                                  size: 12, color: AppColors.emerald500),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: TerminalPane(
        terminals: _terminals,
        onFollowUp: _openFollowUp,
      ),
    );
  }
}
