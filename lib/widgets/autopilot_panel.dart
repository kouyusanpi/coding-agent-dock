import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/agent_cli.dart';
import '../models/autopilot_plan.dart';
import '../models/autopilot_run_record.dart';
import '../services/autopilot_engine.dart';
import '../services/autopilot_llm.dart';
import '../services/autopilot_manager.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Right-side docked panel for the Autopilot autonomous coding loop.
///
/// Layout (top → bottom):
///   header (status chip + close) → run-info card (project / agent /
///   session / LLM / quiet countdown) → LLM connection config (collapsible)
///   → goal form → live checklist → timeline log.
///
/// The panel is embedded in the home screen's body row (left sidebar |
/// terminal | autopilot), not a dialog — closing it only hides the panel;
/// a running loop keeps going in the background.
class AutopilotPanel extends StatefulWidget {
  static const double defaultWidth = 420;
  static const double minWidth = 320;
  static const double maxWidth = 760;
  static const Key dividerKey = Key('autopilot_panel_divider');

  final AutopilotManager manager;
  final List<AgentCli> agents;
  final String? initialWorkingDirectory;

  /// Persist + re-apply LLM connection settings.
  final void Function()? onConfigChanged;

  /// Hide the panel (the loop keeps running).
  final VoidCallback? onClose;

  /// Focus the terminal tab of the given session id.
  final void Function(int sessionId)? onShowSession;

  /// Reopen a finished run's terminal, run the agent's `/resume` (auto-select
  /// first entry), then re-engage the autopilot to plan the next step from the
  /// restored history. Used by the history list.
  final void Function(AutopilotRunRecord record)? onResumeRun;

  const AutopilotPanel({
    super.key,
    required this.manager,
    required this.agents,
    this.initialWorkingDirectory,
    this.onConfigChanged,
    this.onClose,
    this.onShowSession,
    this.onResumeRun,
  });

  @override
  State<AutopilotPanel> createState() => _AutopilotPanelState();
}

enum _AutopilotViewMode { runs, history }

class _AutopilotPanelState extends State<AutopilotPanel> {
  final _baseUrlCtrl = TextEditingController(
    text: SettingsService.autopilotBaseUrl,
  );
  final _apiKeyCtrl = TextEditingController(
    text: SettingsService.autopilotApiKey,
  );
  final _modelCtrl = TextEditingController(
    text: SettingsService.autopilotModel,
  );
  final _quietSecondsCtrl = TextEditingController(
    text: '${SettingsService.autopilotQuietSeconds}',
  );
  final _maxIterationsCtrl = TextEditingController(
    text: '${SettingsService.autopilotMaxIterations}',
  );
  final _outputTailCtrl = TextEditingController(
    text: '${SettingsService.autopilotOutputTailLines}',
  );
  final _planPromptCtrl = TextEditingController(
    text: SettingsService.autopilotPlanPrompt,
  );
  final _decidePromptCtrl = TextEditingController(
    text: SettingsService.autopilotDecidePrompt,
  );
  final _goalCtrl = TextEditingController();
  final _taskSystemCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  String? _agentId;
  _AutopilotViewMode _viewMode = _AutopilotViewMode.runs;
  Timer? _uiTimer;

  /// Run id → set of expanded LLM-interaction indices. Each call card is
  /// collapsed by default; the user taps to reveal its request/response.
  final Map<String, Set<int>> _expandedInteractions = {};

  List<AgentCli> get _detected =>
      widget.agents.where((a) => a.detected).toList();

  @override
  void initState() {
    super.initState();
    _agentId = _detected.isNotEmpty ? _detected.first.id : null;
    _dirCtrl.text = widget.initialWorkingDirectory ?? '';
    widget.manager.addListener(_onManager);
    // 1s ticker refreshes the quiet-countdown while the agent works.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final selected = widget.manager.selectedEngine;
      if (mounted && selected?.state == AutopilotState.waitingAgent) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    widget.manager.removeListener(_onManager);
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _quietSecondsCtrl.dispose();
    _maxIterationsCtrl.dispose();
    _outputTailCtrl.dispose();
    _planPromptCtrl.dispose();
    _decidePromptCtrl.dispose();
    _goalCtrl.dispose();
    _taskSystemCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  void _onManager() {
    if (mounted) setState(() {});
  }

  bool get _canStart =>
      _goalCtrl.text.trim().isNotEmpty &&
      _modelCtrl.text.trim().isNotEmpty &&
      _baseUrlCtrl.text.trim().isNotEmpty &&
      _agentId != null;

  Future<void> _saveConfig() async {
    await SettingsService.setAutopilotBaseUrl(_baseUrlCtrl.text);
    await SettingsService.setAutopilotApiKey(_apiKeyCtrl.text);
    await SettingsService.setAutopilotModel(_modelCtrl.text);
    final quietSeconds =
        int.tryParse(_quietSecondsCtrl.text.trim()) ??
        SettingsService.autopilotQuietSeconds;
    final maxIterations =
        int.tryParse(_maxIterationsCtrl.text.trim()) ??
        SettingsService.autopilotMaxIterations;
    final outputTailLines =
        int.tryParse(_outputTailCtrl.text.trim()) ??
        SettingsService.autopilotOutputTailLines;
    await SettingsService.setAutopilotQuietSeconds(quietSeconds);
    await SettingsService.setAutopilotMaxIterations(maxIterations);
    await SettingsService.setAutopilotOutputTailLines(outputTailLines);
    await SettingsService.setAutopilotPlanPrompt(_planPromptCtrl.text);
    await SettingsService.setAutopilotDecidePrompt(_decidePromptCtrl.text);
    widget.onConfigChanged?.call();
  }

  /// Per-task system prompt appended to the (user-owned) base prompt for this
  /// run only. The base planning/decision prompts live in the settings dialog.
  String? _effectiveSystemPrompt() {
    final task = _taskSystemCtrl.text.trim();
    return task.isEmpty ? null : task;
  }

  Future<void> _start() async {
    if (!_canStart) return;
    await _saveConfig();
    final dir = _dirCtrl.text.trim();
    await widget.manager.startRun(
      goal: _goalCtrl.text.trim(),
      agentId: _agentId!,
      workingDirectory: dir.isEmpty ? null : dir,
      systemPrompt: _effectiveSystemPrompt(),
    );
  }

  String _agentName(String id) =>
      widget.agents
          .where((a) => a.id == id)
          .map((a) => a.displayName)
          .firstOrNull ??
      id;

  void _useRecordAsDraft(AutopilotRunRecord record) {
    setState(() {
      _goalCtrl.text = record.goal;
      _dirCtrl.text = record.workingDirectory ?? '';
      _agentId = record.agentId;
      _viewMode = _AutopilotViewMode.runs;
    });
  }

  void _switchViewMode(_AutopilotViewMode mode) {
    final targetRecord = switch (mode) {
      _AutopilotViewMode.runs => widget.manager.runningRecords.firstOrNull,
      _AutopilotViewMode.history => widget.manager.historyRecords.firstOrNull,
    };
    setState(() => _viewMode = mode);
    if (targetRecord != null) {
      widget.manager.selectRun(targetRecord.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runningRecords = widget.manager.runningRecords;
    final historyRecords = widget.manager.historyRecords;
    AutopilotRunRecord? selectedRecord = widget.manager.selectedRecord;
    if (_viewMode == _AutopilotViewMode.runs &&
        selectedRecord != null &&
        !runningRecords.any((record) => record.id == selectedRecord!.id)) {
      selectedRecord = runningRecords.firstOrNull;
    }
    if (_viewMode == _AutopilotViewMode.history &&
        selectedRecord != null &&
        !historyRecords.any((record) => record.id == selectedRecord!.id)) {
      selectedRecord = historyRecords.firstOrNull;
    }
    final selectedEngine = selectedRecord == null
        ? null
        : widget.manager.engines
              .where((engine) => engine.currentRecord?.id == selectedRecord!.id)
              .firstOrNull;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg900,
        border: Border(left: BorderSide(color: AppColors.border800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(selectedEngine, selectedRecord),
          const Divider(height: 1, color: AppColors.border800),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_viewMode == _AutopilotViewMode.runs) ...[
                    if (!_llmConfigured()) _configHint(),
                    _goalSection(),
                    const SizedBox(height: 14),
                    _runningSection(),
                    const SizedBox(height: 14),
                    if (selectedRecord != null)
                      _selectedRunSection(selectedEngine, selectedRecord)
                    else
                      _emptySelection(),
                  ] else ...[
                    _historySection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AutopilotEngine? engine, AutopilotRunRecord? record) {
    final runningCount = widget.manager.runningRecords.length;
    final historyCount = widget.manager.historyRecords.length;
    final (label, color) = record == null
        ? ('待机', AppColors.text500)
        : _recordStatusMeta(record.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            color: AppColors.accent400,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text('Autopilot', style: AppTypography.cardTitle),
          const SizedBox(width: 8),
          _modeToggle(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$runningCount 运行中 · $historyCount 历史',
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta.copyWith(
                fontSize: 10,
                color: AppColors.text500,
                fontFamily: 'Menlo',
              ),
            ),
          ),
          const Spacer(),
          if (engine != null && engine.isRunning)
            IconButton(
              icon: const Icon(Icons.stop, size: 16, color: AppColors.red400),
              onPressed: engine.stop,
              tooltip: '停止当前选中的 Autopilot',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              size: 16,
              color: _llmConfigured()
                  ? AppColors.text500
                  : AppColors.labelYellow,
            ),
            onPressed: _openSettings,
            tooltip: 'LLM 与全局配置',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.text500),
            onPressed: widget.onClose,
            tooltip: '隐藏面板（循环继续后台运行）',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent400.withAlpha(30)
                : AppColors.bg800,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accent400 : AppColors.border800,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.meta.copyWith(
              fontSize: 10,
              color: selected ? AppColors.accent400 : AppColors.text500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(
          label: '运行',
          selected: _viewMode == _AutopilotViewMode.runs,
          onTap: () => _switchViewMode(_AutopilotViewMode.runs),
        ),
        const SizedBox(width: 6),
        chip(
          label: '历史',
          selected: _viewMode == _AutopilotViewMode.history,
          onTap: () => _switchViewMode(_AutopilotViewMode.history),
        ),
      ],
    );
  }

  /// Live run context: project dir, agent + session, LLM endpoint, progress.
  Widget _runInfoCard(
    AutopilotEngine? engine,
    AutopilotRunRecord record, {
    bool isHistory = false,
  }) {
    final canOpen = record.sessionId != null &&
        (isHistory
            ? widget.onResumeRun != null
            : widget.onShowSession != null);
    final baseHost =
        Uri.tryParse(SettingsService.autopilotBaseUrl)?.host ??
        SettingsService.autopilotBaseUrl;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent400.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            Icons.folder_outlined,
            '项目',
            record.workingDirectory ?? '（agent 默认目录）',
          ),
          const SizedBox(height: 5),
          _infoRow(
            Icons.terminal,
            'Agent',
            record.sessionId != null
                ? '${_agentName(record.agentId)} · 会话 #${record.sessionId}'
                : _agentName(record.agentId),
            trailing: canOpen
                ? GestureDetector(
                    onTap: () => isHistory
                        ? widget.onResumeRun!(record)
                        : widget.onShowSession!(record.sessionId!),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        isHistory ? '恢复并继续 →' : '打开终端 →',
                        style: AppTypography.meta.copyWith(
                          color: AppColors.accent400,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 5),
          _infoRow(
            Icons.psychology_outlined,
            'LLM',
            '${SettingsService.autopilotModel} @ $baseHost',
          ),
          const SizedBox(height: 5),
          _infoRow(
            Icons.loop,
            '迭代',
            engine != null
                ? '${engine.iteration} / ${engine.maxIterations}'
                      '${engine.state == AutopilotState.waitingAgent ? '   静默 ${engine.secondsQuiet}s / ${engine.quietSeconds}s' : ''}'
                : '${record.iteration} · ${record.doneSteps}/${record.totalSteps} 步',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: AppColors.text500),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            label,
            style: AppTypography.meta.copyWith(
              fontSize: 10,
              color: AppColors.text500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.meta.copyWith(
              fontSize: 10,
              color: AppColors.text200,
              fontFamily: 'Menlo',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ],
    );
  }

  /// Whether the LLM endpoint is configured enough to start a run.
  bool _llmConfigured() =>
      _baseUrlCtrl.text.trim().isNotEmpty && _modelCtrl.text.trim().isNotEmpty;

  /// Inline hint shown in the runs view when the LLM hasn't been configured —
  /// nudges the user to open the settings dialog (it's no longer inline).
  Widget _configHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.labelYellow.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.labelYellow.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppColors.labelYellow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '尚未配置 LLM，点击右上角 ⚙ 设置 Base URL / API Key / Model',
              style: AppTypography.meta.copyWith(
                fontSize: 10,
                color: AppColors.text400,
              ),
            ),
          ),
          TextButton(
            onPressed: _openSettings,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.labelYellow,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('去配置', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  /// One-time configuration dialog: LLM connection, loop tunables, and the
  /// global system prompt. Kept out of the runs view so the panel has more room
  /// for live run detail.
  Future<void> _openSettings() async {
    var apiKeyVisible = false;
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            return Dialog(
              backgroundColor: AppColors.bg900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border800),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.settings_outlined,
                            size: 16,
                            color: AppColors.accent400,
                          ),
                          const SizedBox(width: 8),
                          Text('Autopilot 配置', style: AppTypography.cardTitle),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.text500,
                            ),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border800),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel('LLM 连接（OpenAI 兼容）'),
                            const SizedBox(height: 8),
                            _label('Base URL'),
                            const SizedBox(height: 3),
                            _field(
                              _baseUrlCtrl,
                              hint: 'https://api.deepseek.com/v1',
                            ),
                            const SizedBox(height: 8),
                            _label('API Key'),
                            const SizedBox(height: 3),
                            _field(
                              _apiKeyCtrl,
                              hint: 'sk-…',
                              obscure: !apiKeyVisible,
                              suffix: IconButton(
                                icon: Icon(
                                  apiKeyVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 13,
                                  color: AppColors.text500,
                                ),
                                onPressed: () =>
                                    setLocal(() => apiKeyVisible = !apiKeyVisible),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _label('Model'),
                            const SizedBox(height: 3),
                            _field(
                              _modelCtrl,
                              hint: 'deepseek-chat · gpt-4o · qwen-max',
                            ),
                            const SizedBox(height: 16),
                            _sectionLabel('循环参数'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('静默秒数'),
                                      const SizedBox(height: 3),
                                      _field(_quietSecondsCtrl, hint: '30'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('最大迭代'),
                                      const SizedBox(height: 3),
                                      _field(_maxIterationsCtrl, hint: '20'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('采样行数'),
                                      const SizedBox(height: 3),
                                      _field(_outputTailCtrl, hint: '120'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _promptTemplateHeader(
                              '规划 System 提示词',
                              onReset: () => setLocal(() {
                                _planPromptCtrl.text =
                                    OpenAiCompatLlm.defaultPlanPrompt;
                              }),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '把目标拆成 checklist 时发给 LLM。需保留 JSON 数组输出格式，否则无法解析。',
                              style: AppTypography.meta.copyWith(
                                fontSize: 9,
                                color: AppColors.text500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _field(_planPromptCtrl, hint: '', maxLines: 6),
                            const SizedBox(height: 16),
                            _promptTemplateHeader(
                              '评估 System 提示词',
                              onReset: () => setLocal(() {
                                _decidePromptCtrl.text =
                                    OpenAiCompatLlm.defaultDecidePrompt;
                              }),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '每轮读取终端输出后发给 LLM 决定下一步。需保留 JSON 对象输出格式。',
                              style: AppTypography.meta.copyWith(
                                fontSize: 9,
                                color: AppColors.text500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _field(_decidePromptCtrl, hint: '', maxLines: 8),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border800),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _saveConfig();
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('配置已保存'),
                                    duration: Duration(milliseconds: 1000),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.save_outlined, size: 14),
                            label: const Text(
                              '保存',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: AppTypography.sectionHeader.copyWith(fontSize: 12),
  );

  Widget _promptTemplateHeader(String title, {required VoidCallback onReset}) {
    return Row(
      children: [
        Expanded(child: _sectionLabel(title)),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt, size: 13),
          label: const Text('恢复默认', style: TextStyle(fontSize: 10)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text400,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _goalSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('目标'),
          const SizedBox(height: 3),
          _field(
            _goalCtrl,
            hint: '描述要完成的开发目标 — LLM 会拆解为 checklist 并逐步驱动 agent…',
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _label('本任务 System 提示词（可选，仅本次，叠加在全局之上）'),
          const SizedBox(height: 3),
          _field(
            _taskSystemCtrl,
            hint: '为这个任务追加专属约束…',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          _label('Coding Agent'),
          const SizedBox(height: 3),
          _agentDropdown(enabled: true),
          const SizedBox(height: 8),
          _label('项目目录（可选）'),
          const SizedBox(height: 3),
          _field(_dirCtrl, hint: '/path/to/project', enabled: true),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _canStart ? _start : null,
            icon: const Icon(Icons.add_task, size: 14),
            label: const Text('新增 Autopilot', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _runningSection() {
    final records = widget.manager.runningRecords;
    return _recordSection(
      title: '运行中',
      records: records,
      emptyText: '当前没有运行中的 Autopilot',
      isHistory: false,
    );
  }

  Widget _historySection() {
    final records = widget.manager.historyRecords.take(12).toList();
    return _recordSection(
      title: '历史记录',
      records: records,
      emptyText: '暂无 Autopilot 历史记录',
      isHistory: true,
    );
  }

  Widget _recordSection({
    required String title,
    required List<AutopilotRunRecord> records,
    required String emptyText,
    required bool isHistory,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppTypography.sectionHeader),
            const SizedBox(width: 8),
            Text(
              '${records.length}',
              style: AppTypography.meta.copyWith(
                fontFamily: 'Menlo',
                color: AppColors.text500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bg950,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border800),
            ),
            child: Text(
              emptyText,
              style: AppTypography.meta.copyWith(color: AppColors.text500),
            ),
          )
        else
          ...records.map((record) => _recordRow(record, isHistory: isHistory)),
      ],
    );
  }

  Widget _selectedRunSection(
    AutopilotEngine? engine,
    AutopilotRunRecord record,
  ) {
    final isHistoryRecord = !widget.manager.runningRecords.any(
      (item) => item.id == record.id,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选中任务', style: AppTypography.sectionHeader),
        const SizedBox(height: 6),
        _runInfoCard(engine, record, isHistory: isHistoryRecord),
        if (engine != null) ...[
          const SizedBox(height: 10),
          _monitoringCard(engine),
        ],
        if (isHistoryRecord) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _useRecordAsDraft(record),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent400,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.replay, size: 14),
              label: const Text('重新开始', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
        if (engine != null && engine.checklist.isNotEmpty) ...[
          const SizedBox(height: 14),
          _checklistSection(engine),
        ],
        if (engine != null && engine.interactions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _interactionsSection(engine, record.id),
        ],
        if (engine != null && engine.log.isNotEmpty) ...[
          const SizedBox(height: 14),
          _timelineSection(engine),
        ],
      ],
    );
  }

  Widget _monitoringCard(AutopilotEngine engine) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '静默监控',
            style: AppTypography.sectionHeader.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Coding Agent 连续 ${engine.quietSeconds}s 没有输出后，会抓取最近 '
            '${engine.outputTailLines} 行终端内容，交给 LLM 判断是发送“继续”还是生成下一步任务。',
            style: AppTypography.meta.copyWith(
              fontSize: 10,
              color: AppColors.text400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySelection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg950,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border800),
      ),
      child: Text(
        '选择一个运行中任务或历史记录以查看详情',
        style: AppTypography.meta.copyWith(color: AppColors.text500),
      ),
    );
  }

  Widget _checklistSection(AutopilotEngine engine) {
    final items = engine.checklist;
    final doneCount = items
        .where((i) => i.status == ChecklistStatus.done)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Checklist', style: AppTypography.sectionHeader),
            const SizedBox(width: 8),
            Text(
              '$doneCount/${items.length}',
              style: AppTypography.meta.copyWith(
                fontFamily: 'Menlo',
                color: AppColors.emerald500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map(_checklistRow),
      ],
    );
  }

  Widget _recordRow(AutopilotRunRecord record, {required bool isHistory}) {
    final (label, color) = _recordStatusMeta(record.status);
    final agent = _agentName(record.agentId);
    final isCurrent = widget.manager.selectedRunId == record.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.bg950,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrent
              ? AppColors.accent400.withAlpha(90)
              : AppColors.border800,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isHistory ? null : () => widget.manager.selectRun(record.id),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.goal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 11,
                          color: AppColors.text200,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withAlpha(70)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      agent,
                      style: AppTypography.meta.copyWith(
                        fontSize: 10,
                        color: AppColors.text400,
                      ),
                    ),
                    Text(
                      '${record.doneSteps}/${record.totalSteps} 步',
                      style: AppTypography.meta.copyWith(
                        fontFamily: 'Menlo',
                        fontSize: 10,
                        color: AppColors.text500,
                      ),
                    ),
                    Text(
                      _recordTimeRange(record),
                      style: AppTypography.meta.copyWith(
                        fontFamily: 'Menlo',
                        fontSize: 10,
                        color: AppColors.text500,
                      ),
                    ),
                  ],
                ),
                if (record.detail != null &&
                    record.detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    record.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(
                      fontSize: 10,
                      color: AppColors.text500,
                    ),
                  ),
                ],
                if (record.sessionId != null &&
                    (isHistory
                        ? widget.onResumeRun != null
                        : widget.onShowSession != null)) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => isHistory
                              ? widget.onResumeRun!(record)
                              : widget.onShowSession!(record.sessionId!),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent400,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isHistory
                                ? '恢复并继续 #${record.sessionId}'
                                : '打开终端 #${record.sessionId}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        if (isHistory)
                          TextButton(
                            onPressed: () => _useRecordAsDraft(record),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accent400,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '重新开始',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else if (isHistory) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _useRecordAsDraft(record),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent400,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('重新开始', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checklistRow(ChecklistItem item) {
    final (icon, color) = switch (item.status) {
      ChecklistStatus.pending => (
        Icons.radio_button_unchecked,
        AppColors.text500,
      ),
      ChecklistStatus.inProgress => (Icons.sync, AppColors.accent400),
      ChecklistStatus.done => (Icons.check_circle, AppColors.emerald500),
      ChecklistStatus.failed => (Icons.error_outline, AppColors.red400),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              item.title,
              style: AppTypography.body.copyWith(
                fontSize: 11,
                color: item.status == ChecklistStatus.done
                    ? AppColors.text500
                    : AppColors.text200,
                decoration: item.status == ChecklistStatus.done
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Expandable inspector listing every LLM round-trip (plan + evaluations).
  /// Each card is collapsed by default; tapping reveals the full request sent
  /// to the model and the raw response it returned.
  Widget _interactionsSection(AutopilotEngine engine, String runId) {
    final interactions = engine.interactions.reversed.toList();
    final expanded = _expandedInteractions[runId] ?? const {};
    final anyExpanded = expanded.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('LLM 调用', style: AppTypography.sectionHeader),
            const SizedBox(width: 8),
            Text(
              '${engine.interactions.length}',
              style: AppTypography.meta.copyWith(
                fontFamily: 'Menlo',
                color: AppColors.text500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                if (anyExpanded) {
                  _expandedInteractions[runId] = {};
                } else {
                  _expandedInteractions[runId] = engine.interactions
                      .map((e) => e.index)
                      .toSet();
                }
              }),
              child: Text(
                anyExpanded ? '全部收起' : '全部展开',
                style: AppTypography.meta.copyWith(
                  fontSize: 10,
                  color: AppColors.accent400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...interactions.map((it) => _interactionCard(it, runId, expanded)),
      ],
    );
  }

  Widget _interactionCard(
    AutopilotInteraction it,
    String runId,
    Set<int> expandedSet,
  ) {
    final isExpanded = expandedSet.contains(it.index);
    final (phaseLabel, phaseColor) = switch (it.phase) {
      AutopilotPhase.plan => ('规划', AppColors.accent400),
      AutopilotPhase.evaluate => ('评估', AppColors.emerald500),
    };
    final statusColor = it.ok ? AppColors.text500 : AppColors.red400;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.bg950,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: it.ok ? AppColors.border800 : AppColors.red400.withAlpha(70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Collapsed header (always visible, tappable) ---
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() {
                final set = _expandedInteractions[runId] ??= {};
                if (!set.remove(it.index)) set.add(it.index);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 15,
                          color: AppColors.text500,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '#${it.index}',
                          style: AppTypography.meta.copyWith(
                            fontFamily: 'Menlo',
                            fontSize: 10,
                            color: AppColors.text500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _miniBadge(phaseLabel, phaseColor),
                        if (it.phase == AutopilotPhase.evaluate) ...[
                          const SizedBox(width: 4),
                          Text(
                            '迭代 ${it.iteration}',
                            style: AppTypography.meta.copyWith(
                              fontSize: 9,
                              color: AppColors.text500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (!it.ok)
                          const Icon(
                            Icons.error_outline,
                            size: 12,
                            color: AppColors.red400,
                          ),
                        if (!it.ok) const SizedBox(width: 4),
                        Text(
                          _fmtMs(it.durationMs),
                          style: AppTypography.meta.copyWith(
                            fontFamily: 'Menlo',
                            fontSize: 9,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.only(left: 19),
                      child: Text(
                        it.error ?? it.summary ?? '（无摘要）',
                        maxLines: isExpanded ? null : 2,
                        overflow: isExpanded ? null : TextOverflow.ellipsis,
                        style: AppTypography.meta.copyWith(
                          fontSize: 10,
                          color: it.ok ? AppColors.text400 : AppColors.red400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // --- Expanded body: terminal snapshot + request + response ---
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border800),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (it.phase == AutopilotPhase.evaluate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _transcriptBlock(
                        '① 终端历史快照（读取后喂给 LLM）',
                        (it.agentOutput == null || it.agentOutput!.isEmpty)
                            ? '（本轮未读取到终端内容 — agent 可能用了全屏界面）'
                            : it.agentOutput!,
                        Icons.terminal,
                        AppColors.text400,
                      ),
                    ),
                  _transcriptBlock(
                    it.phase == AutopilotPhase.evaluate
                        ? '② 请求（发送给大模型，含上面的快照）'
                        : '① 请求（发送给大模型）',
                    it.request.isEmpty ? '（无 — 请求未发出）' : it.request,
                    Icons.north_east,
                    AppColors.accent400,
                  ),
                  const SizedBox(height: 8),
                  _transcriptBlock(
                    it.phase == AutopilotPhase.evaluate
                        ? '③ 响应（大模型返回）'
                        : '② 响应（大模型返回）',
                    it.response.isEmpty ? '（无 — 未收到响应）' : it.response,
                    Icons.south_west,
                    AppColors.emerald500,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _transcriptBlock(
    String label,
    String content,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.meta.copyWith(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制'),
                      duration: Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Icon(
                Icons.copy_all_outlined,
                size: 12,
                color: AppColors.text500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bg900,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border800),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              primary: false,
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: AppColors.text200,
                  fontFamily: 'Menlo',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(70)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
    ),
  );

  static String _fmtMs(int ms) =>
      ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s';

  Widget _timelineSection(AutopilotEngine engine) {
    final entries = engine.log.reversed.take(50).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('运行日志', style: AppTypography.sectionHeader),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bg950,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fmtTime(e.time),
                          style: AppTypography.meta.copyWith(
                            fontFamily: 'Menlo',
                            fontSize: 9,
                            color: AppColors.text500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.message,
                            style: AppTypography.meta.copyWith(
                              fontSize: 10,
                              color: AppColors.text400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  static (String, Color) _recordStatusMeta(String status) => switch (status) {
    'planning' => ('规划中', AppColors.accent400),
    'evaluating' => ('评估中', AppColors.accent400),
    'running' => ('运行中', AppColors.emerald500),
    'done' => ('完成', AppColors.emerald500),
    'failed' => ('失败', AppColors.red400),
    'stopped' => ('已停止', AppColors.text500),
    _ => ('待机', AppColors.text500),
  };

  String _recordTimeRange(AutopilotRunRecord record) {
    final start = _fmtTime(record.startedAt);
    final end = record.endedAt == null ? '...' : _fmtTime(record.endedAt!);
    return '$start-$end';
  }

  Widget _label(String text) => Text(
    text,
    style: AppTypography.meta.copyWith(color: AppColors.text400, fontSize: 10),
  );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    int maxLines = 1,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: obscure ? 1 : maxLines,
      obscureText: obscure,
      enabled: enabled,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.text200,
        fontFamily: 'Menlo',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, color: AppColors.text500),
        filled: true,
        fillColor: AppColors.bg900,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent400),
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _agentDropdown({required bool enabled}) {
    final detected = _detected;
    if (detected.isEmpty) {
      return const Text(
        '未检测到 agent',
        style: TextStyle(fontSize: 11, color: AppColors.text500),
      );
    }
    final validId = detected.any((a) => a.id == _agentId)
        ? _agentId
        : detected.first.id;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bg900,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border800),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validId,
          isExpanded: true,
          dropdownColor: AppColors.bg900,
          style: const TextStyle(fontSize: 11, color: AppColors.text200),
          iconSize: 14,
          iconEnabledColor: AppColors.text500,
          items: detected
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    a.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.text200,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? (v) => setState(() => _agentId = v) : null,
        ),
      ),
    );
  }
}
