import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../models/agent_cli.dart';
import '../models/claude_settings.dart';
import '../services/claude_settings_service.dart';
import '../services/settings_service.dart';
import '../services/workspace_detector_service.dart';
import '../database/database.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Modal dialog for creating a new agent CLI session.
///
/// Supports multi-dispatch: when [clis] contains more than one agent the
/// dialog creates one session per agent (same name/workspace/input) and
/// calls [onCreated] for each — the caller opens each in its own terminal.
class NewSessionDialog extends StatefulWidget {
  /// The agents to dispatch to. Usually one; two or more = multi-dispatch.
  final List<AgentCli> clis;
  final SessionManager sessionManager;
  final ValueChanged<TaskSession> onCreated;
  /// Pre-fill the prompt input field (e.g. from clipboard or relay).
  final String? initialPrompt;
  /// Pre-fill the workspace path field (e.g. "Continue here" from a prior session).
  final String? initialWorkingDirectory;
  /// Called when the user taps "Save as template" with the current form state.
  /// Receives (name, agentId, workingDirectory, prompt).
  final void Function(String name, String agentId, String? workingDir, String prompt)? onSaveTemplate;

  const NewSessionDialog({
    super.key,
    required this.clis,
    required this.sessionManager,
    required this.onCreated,
    this.initialPrompt,
    this.initialWorkingDirectory,
    this.onSaveTemplate,
  });

  static Future<void> show(
    BuildContext context, {
    required List<AgentCli> clis,
    required SessionManager sessionManager,
    required ValueChanged<TaskSession> onCreated,
    String? initialPrompt,
    String? initialWorkingDirectory,
    void Function(String name, String agentId, String? workingDir, String prompt)? onSaveTemplate,
  }) {
    assert(clis.isNotEmpty);
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.black60,
      barrierDismissible: true,
      builder: (_) => NewSessionDialog(
        clis: clis,
        sessionManager: sessionManager,
        onCreated: onCreated,
        initialPrompt: initialPrompt,
        initialWorkingDirectory: initialWorkingDirectory,
        onSaveTemplate: onSaveTemplate,
      ),
    );
  }

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  final _workspaceCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _inputCtl = TextEditingController();
  final _customArgsCtl = TextEditingController();

  /// When true, the user takes manual control of the launch arguments — the
  /// auto-generated flags (and the Claude options panel) are bypassed. An empty
  /// field then means "launch the bare command with no flags".
  bool _useCustomArgs = false;

  bool _creating = false;
  bool _nameEdited = false; // user manually changed the name field
  late ClaudeSettings _claudeSettings;
  bool _panelExpanded = true;
  List<String> _recentDirs = [];
  List<String> _recentPrompts = [];
  List<({String name, String path})> _bookmarks = [];
  bool _detecting = false;

  List<Map<String, String>> _modelOptions(AppLocalizations l10n) => [
        {'key': 'opus', 'label': l10n.modelDefaultLabel},
        {'key': 'sonnet', 'label': l10n.modelSonnetLabel},
        {'key': 'haiku', 'label': l10n.modelHaikuLabel},
        {'key': 'claude-opus-4-8', 'label': l10n.modelOpusPinned},
        {'key': 'claude-sonnet-4-6', 'label': l10n.modelSonnetPinned},
      ];

  String _effortLabel(AppLocalizations l10n, ClaudeEffort e) => switch (e) {
        ClaudeEffort.low => l10n.effortLow,
        ClaudeEffort.medium => l10n.effortMedium,
        ClaudeEffort.high => l10n.effortHigh,
        ClaudeEffort.xhigh => l10n.effortXhigh,
        ClaudeEffort.max => l10n.effortMax,
      };

  String _permLabel(AppLocalizations l10n, ClaudePermissionMode m) =>
      switch (m) {
        ClaudePermissionMode.defaultMode => l10n.permDefault,
        ClaudePermissionMode.acceptEdits => l10n.permAcceptEdits,
        ClaudePermissionMode.auto => l10n.permAuto,
        ClaudePermissionMode.bypassPermissions => l10n.permBypass,
        ClaudePermissionMode.dontAsk => l10n.permDontAsk,
        ClaudePermissionMode.plan => l10n.permPlan,
      };

  AgentCli get _primaryCli => widget.clis.first;
  bool get _isMulti => widget.clis.length > 1;
  bool get _isClaude => _primaryCli.id == 'claude';

  /// The session name to use: the explicit name field if the user typed one,
  /// otherwise the first 40 chars of the prompt (trimmed, collapsed whitespace).
  String get _effectiveName {
    final explicit = _nameCtl.text.trim();
    if (explicit.isNotEmpty) return explicit;
    final prompt = _inputCtl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (prompt.isEmpty) return '';
    return prompt.length > 40 ? '${prompt.substring(0, 40)}…' : prompt;
  }

  @override
  void initState() {
    super.initState();
    _claudeSettings = const ClaudeSettings();
    if (_isClaude) {
      _panelExpanded = true;
      ClaudeSettingsService.load('claude').then((s) {
        if (mounted) setState(() => _claudeSettings = s);
      });
    }
    widget.sessionManager.recentWorkingDirectories().then((dirs) {
      if (mounted) setState(() => _recentDirs = dirs);
    });
    widget.sessionManager.recentPrompts().then((prompts) {
      if (mounted) setState(() => _recentPrompts = prompts);
    });
    _bookmarks = SettingsService.workspaceBookmarks;
    // Pre-fill from clipboard / follow-up source.
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _inputCtl.text = widget.initialPrompt!;
    }
    if (widget.initialWorkingDirectory != null &&
        widget.initialWorkingDirectory!.isNotEmpty) {
      _workspaceCtl.text = widget.initialWorkingDirectory!;
    }
    // Auto-update name from prompt while user hasn't manually edited it.
    _inputCtl.addListener(() {
      if (!_nameEdited) setState(() {});
    });
  }

  @override
  void dispose() {
    _workspaceCtl.dispose();
    _nameCtl.dispose();
    _inputCtl.dispose();
    _customArgsCtl.dispose();
    _modelCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDir() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null) _workspaceCtl.text = result;
  }

  Future<void> _detectWorkspace() async {
    if (_detecting || _creating) return;
    setState(() => _detecting = true);
    try {
      final suggestions = await WorkspaceDetectorService.detect();
      if (!mounted) return;
      if (suggestions.isEmpty) return;
      if (suggestions.length == 1) {
        setState(() => _workspaceCtl.text = suggestions.first.path);
        return;
      }
      // Show a small overlay menu to pick from multiple suggestions.
      final chosen = await showMenu<String>(
        context: context,
        color: AppColors.bg800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border700),
        ),
        position: const RelativeRect.fromLTRB(80, 200, 80, 0),
        items: suggestions
            .map((s) => PopupMenuItem<String>(
                  value: s.path,
                  height: 44,
                  child: Row(children: [
                    Text(
                      s.source,
                      style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 10,
                          color: AppColors.accent400),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _shortPath(s.path),
                        style: AppTypography.body
                            .copyWith(color: AppColors.text200),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ))
            .toList(),
      );
      if (chosen != null && mounted) {
        setState(() => _workspaceCtl.text = chosen);
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  String _shortPath(String path) {
    final home = Platform.environment['HOME'] ?? '';
    if (path.startsWith(home)) return '~${path.substring(home.length)}';
    return path;
  }

  Future<void> _addBookmark() async {
    final path = _workspaceCtl.text.trim();
    if (path.isEmpty) return;

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final nameCtl = TextEditingController(
      text: segments.isNotEmpty ? segments.last : path,
    );
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: AppColors.bg900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border700),
          ),
          title: Text(dl10n.addBookmark, style: AppTypography.cardTitle),
          content: TextField(
            controller: nameCtl,
            autofocus: true,
            style: AppTypography.body,
            decoration: InputDecoration(
              hintText: dl10n.bookmarkNameHint,
              hintStyle: AppTypography.bodySmall,
              filled: true,
              fillColor: AppColors.bg800,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border800)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border800)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent400)),
            ),
            onSubmitted: (_) => Navigator.of(ctx).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(foregroundColor: AppColors.text400),
              child: Text(dl10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent400,
                foregroundColor: AppColors.bg950,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(dl10n.save),
            ),
          ],
        );
      },
    );

    final name = nameCtl.text.trim();
    nameCtl.dispose();

    if (confirmed != true || name.isEmpty || !mounted) return;

    // Replace any existing bookmark for the same path, then append.
    final updated = [
      ..._bookmarks.where((b) => b.path != path),
      (name: name, path: path),
    ];
    await SettingsService.setWorkspaceBookmarks(updated);
    if (!mounted) return;
    setState(() => _bookmarks = updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.bookmarkSaved),
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.bg800,
    ));
  }

  Future<void> _removeBookmark(({String name, String path}) bm) async {
    final updated = _bookmarks.where((b) => b.path != bm.path).toList();
    await SettingsService.setWorkspaceBookmarks(updated);
    if (mounted) setState(() => _bookmarks = updated);
  }

  Future<void> _onCreate() async {
    if (_creating) return;
    final name = _effectiveName;
    if (name.isEmpty) return; // nothing in either field

    setState(() => _creating = true);

    try {
      // Custom args bypass the Claude options panel, so only persist the panel
      // settings when the user is actually using them.
      if (_isClaude && !_useCustomArgs) {
        await ClaudeSettingsService.save('claude', _claudeSettings);
      }

      final wd = _workspaceCtl.text.trim().isEmpty
          ? null
          : _workspaceCtl.text.trim();
      final input = _inputCtl.text.trim();
      // null  → auto-generated flags; ""/"…" → user override (empty = bare).
      final customArgs = _useCustomArgs ? _customArgsCtl.text.trim() : null;

      // Create one session per agent (multi-dispatch when >1 agent selected).
      // Assign a shared batchId so cluster siblings can be found later.
      final batchId = _isMulti ? const Uuid().v4() : null;
      final sessions = <TaskSession>[];
      for (final cli in widget.clis) {
        final id = await widget.sessionManager.createSession(
          name: _isMulti ? '$name [${cli.displayName}]' : name,
          cli: cli,
          workingDirectory: wd,
          input: input,
          batchId: batchId,
          customArgs: customArgs,
        );
        final session = await widget.sessionManager.getSession(id);
        if (session != null) sessions.add(session);
      }

      if (mounted) {
        Navigator.of(context).pop();
        for (final s in sessions) {
          widget.onCreated(s);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.createFailed('$e')),
              backgroundColor: AppColors.red500),
        );
      }
    }
  }

  InputDecoration _input({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodySmall,
        filled: true,
        fillColor: AppColors.bg800,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border800)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border800)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent400)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            _creating ? () {} : _onCreate,
      },
      child: Focus(
        autofocus: false,
        child: Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          decoration: BoxDecoration(
            color: AppColors.bg900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border700),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              _header(l10n),
              const Divider(height: 1, color: AppColors.border700),

              // ── Scrollable body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(l10n.workspacePath, _workspaceField(l10n)),
                      const SizedBox(height: 14),
                      _field(l10n.sessionName, _nameField(l10n)),
                      const SizedBox(height: 14),
                      _field(_isMulti ? l10n.agentsLabel : _primaryCli.displayName, _agentInfo()),
                      const SizedBox(height: 14),
                      _field(l10n.promptInput, _inputField(l10n)),
                      const SizedBox(height: 16),
                      _customArgsSection(l10n),
                      if (_isClaude && !_useCustomArgs) ...[
                        const SizedBox(height: 16),
                        _claudePanel(l10n),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer ──
              const Divider(height: 1, color: AppColors.border700),
              _footer(l10n),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.newSessionTitle, style: AppTypography.cardTitle),
                if (_isMulti)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      l10n.dispatchingToAgents(widget.clis.length),
                      style: AppTypography.meta
                          .copyWith(color: AppColors.accent400),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _creating ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.text400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      );

  Widget _field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 6),
          child,
        ],
      );

  Widget _workspaceField(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _workspaceCtl,
                enabled: !_creating,
                style: AppTypography.body,
                decoration: _input(hint: l10n.workspaceHint),
              ),
            ),
            const SizedBox(width: 8),
            // Bookmark-save button
            Tooltip(
              message: l10n.addBookmark,
              child: IconButton(
                onPressed: _creating ? null : _addBookmark,
                icon: const Icon(Icons.bookmark_add_outlined,
                    size: 18, color: AppColors.accent400),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.border700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _creating ? null : _pickDir,
              icon: const Icon(Icons.folder_open,
                  size: 18, color: AppColors.accent400),
              style: IconButton.styleFrom(
                side: const BorderSide(color: AppColors.border700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Auto-detect from Finder / VS Code / Cursor',
              child: IconButton(
                onPressed: (_creating || _detecting) ? null : _detectWorkspace,
                icon: _detecting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent400),
                      )
                    : const Icon(Icons.travel_explore,
                        size: 18, color: AppColors.accent400),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.border700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
          // Saved bookmarks
          if (_bookmarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final bm in _bookmarks)
                  _buildBookmarkChip(bm),
              ],
            ),
          ],
          // Recent directory suggestions
          if (_recentDirs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final dir in _recentDirs)
                  GestureDetector(
                    onTap: _creating
                        ? null
                        : () => setState(() => _workspaceCtl.text = dir),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bg800,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: AppColors.border700),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history,
                                size: 11, color: AppColors.text500),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 200),
                              child: Text(
                                dir.replaceFirst(
                                    RegExp(r'^.*/'), '…/'),
                                style: AppTypography.meta,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );

  Widget _buildBookmarkChip(({String name, String path}) bm) {
    return GestureDetector(
      onTap: _creating
          ? null
          : () => setState(() => _workspaceCtl.text = bm.path),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
          decoration: BoxDecoration(
            color: AppColors.accent10,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent400.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bookmark_outlined,
                size: 11, color: AppColors.accent400),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                bm.name,
                style: AppTypography.meta
                    .copyWith(color: AppColors.accent400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _creating ? null : () => _removeBookmark(bm),
              child: const Icon(Icons.close,
                  size: 11, color: AppColors.accent400),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _nameField(AppLocalizations l10n) {
    final autoName = _effectiveName;
    return TextField(
      controller: _nameCtl,
      enabled: !_creating,
      style: AppTypography.body,
      onChanged: (_) => setState(() => _nameEdited = true),
      decoration: _input(
        hint: autoName.isNotEmpty ? autoName : l10n.sessionNameHint,
      ).copyWith(
        suffixIcon: _nameEdited
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                color: AppColors.text500,
                tooltip: l10n.resetToAutoName,
                onPressed: () => setState(() {
                  _nameCtl.clear();
                  _nameEdited = false;
                }),
              )
            : null,
        hintStyle: _nameEdited
            ? AppTypography.bodySmall
            : AppTypography.bodySmall.copyWith(
                color: AppColors.text400,
                fontStyle: FontStyle.italic,
              ),
      ),
    );
  }

  Widget _agentInfo() {
    if (!_isMulti) {
      final cli = _primaryCli;
      return Row(children: [
        const Icon(Icons.terminal, size: 16, color: AppColors.text400),
        const SizedBox(width: 8),
        Text(cli.displayName, style: AppTypography.body),
        if (cli.detected && cli.version != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bg800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('v${cli.version}', style: AppTypography.monoSmall),
          ),
        ],
      ]);
    }

    // Multi-dispatch: show a pill for each agent.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final cli in widget.clis)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent400),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.terminal,
                  size: 12, color: AppColors.accent400),
              const SizedBox(width: 5),
              Text(cli.displayName,
                  style: AppTypography.label
                      .copyWith(color: AppColors.accent400)),
            ]),
          ),
      ],
    );
  }

  Widget _inputField(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _inputCtl,
            enabled: !_creating,
            maxLines: 4,
            minLines: 3,
            style: AppTypography.body,
            decoration: _input(hint: l10n.promptHint),
          ),
          if (_recentPrompts.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 22,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recentPrompts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final p = _recentPrompts[i];
                  final label = p.length > 28 ? '${p.substring(0, 28)}…' : p;
                  return GestureDetector(
                    onTap: _creating
                        ? null
                        : () => setState(() {
                              _inputCtl.text = p;
                              _nameEdited = false;
                            }),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bg800,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border700),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history,
                                size: 11, color: AppColors.text500),
                            const SizedBox(width: 4),
                            Text(label, style: AppTypography.meta),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );

  // ── Custom launch arguments ──

  Widget _customArgsSection(AppLocalizations l10n) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border700),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(children: [
              const Icon(Icons.terminal, size: 16, color: AppColors.accent400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.customArgsLabel, style: AppTypography.cardTitle),
                    Text(l10n.customArgsDesc, style: AppTypography.meta),
                  ],
                ),
              ),
              Switch(
                value: _useCustomArgs,
                onChanged: _creating
                    ? null
                    : (v) => setState(() => _useCustomArgs = v),
                activeTrackColor: AppColors.accent400,
              ),
            ]),
          ),
          if (_useCustomArgs) ...[
            const Divider(height: 1, color: AppColors.border700),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _customArgsCtl,
                    enabled: !_creating,
                    style: AppTypography.monoSmall,
                    decoration: _input(hint: l10n.customArgsHint),
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.customArgsEmptyHint, style: AppTypography.meta),
                ],
              ),
            ),
          ],
        ]),
      );

  // ── Claude Code Options Panel ──

  Widget _claudePanel(AppLocalizations l10n) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border700),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            borderRadius: BorderRadius.vertical(top: const Radius.circular(12)),
              onTap: () => setState(() => _panelExpanded = !_panelExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.tune, size: 16, color: AppColors.accent400),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l10n.claudeOptions,
                        style: AppTypography.cardTitle)),
                Icon(
                    _panelExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.text400,
                ),
              ]),
            ),
          ),
          if (_panelExpanded) ...[
            const Divider(height: 1, color: AppColors.border700),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _optField(l10n.modelLabel,
                        child: _modelDropdown(l10n)),
                    const SizedBox(height: 12),
                    _optField(l10n.thinkingLabel,
                        child: _effortSelector(l10n)),
                    const SizedBox(height: 12),
                    _optField(l10n.permissionsLabel,
                        child: _permDropdown(l10n)),
                    const SizedBox(height: 8),
                    _switch(l10n.skipAllPermissions,
                        '--dangerously-skip-permissions',
                        _claudeSettings.dangerouslySkipPermissions,
                        (v) => _claudeSettings =
                            _claudeSettings.copyWith(dangerouslySkipPermissions: v)),
                    _switch(l10n.nonInteractive,
                        l10n.nonInteractiveDesc,
                        _claudeSettings.printMode, (v) =>
                            _claudeSettings = _claudeSettings.copyWith(printMode: v)),
                  ]),
            ),
          ],
        ]),
      );

  Widget _optField(String label, {required Widget child}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 4),
          child,
        ],
      );

  final _modelCtl = TextEditingController();

  Widget _modelDropdown(AppLocalizations l10n) {
    final cur = _claudeSettings.model;
    final knownModels = _modelOptions(l10n);
    final entry = knownModels.cast<Map<String, String>?>().firstWhere(
      (e) => e!['key'] == cur,
      orElse: () => null,
    );
    return Row(children: [
      SizedBox(
        width: 170,
        child: DropdownButtonFormField<String>(
          initialValue: entry != null ? cur : null,
          isExpanded: true,
          style: AppTypography.body,
          dropdownColor: AppColors.bg900,
          decoration: InputDecoration(
            hintText: l10n.quickSelect,
            hintStyle: AppTypography.bodySmall,
            filled: true,
            fillColor: AppColors.bg900,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border800)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border800)),
          ),
          items: [
            for (final m in knownModels)
              DropdownMenuItem(
                value: m['key'],
                child: Text(m['label']!, style: AppTypography.bodySmall),
              ),
          ],
          onChanged: _creating
              ? null
              : (v) {
                  if (v == null) return;
                  _modelCtl.text = v;
                  setState(
                      () => _claudeSettings = _claudeSettings.copyWith(model: v));
                },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: _modelCtl,
          enabled: !_creating,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: l10n.typeModelName,
            hintStyle: AppTypography.bodySmall,
            filled: true,
            fillColor: AppColors.bg900,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border800)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border800)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent400)),
          ),
          onChanged: (v) =>
              setState(() => _claudeSettings = _claudeSettings.copyWith(model: v)),
        ),
      ),
    ]);
  }

  Widget _effortSelector(AppLocalizations l10n) {
    return DropdownButtonFormField<ClaudeEffort>(
      initialValue: _claudeSettings.effort,
      isExpanded: true,
      style: AppTypography.body,
      dropdownColor: AppColors.bg900,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bg900,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border800)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border800)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent400)),
      ),
      items: [
        for (final e in ClaudeEffort.values)
          DropdownMenuItem(
            value: e,
            child: Text(_effortLabel(l10n, e), style: AppTypography.body),
          ),
      ],
      onChanged: _creating
          ? null
          : (v) {
              if (v == null) return;
              setState(() => _claudeSettings = _claudeSettings.copyWith(effort: v));
            },
    );
  }

  Widget _permDropdown(AppLocalizations l10n) {
    final cur = _claudeSettings.permissionMode;
    return DropdownButtonFormField<ClaudePermissionMode>(
      initialValue: cur,
      isExpanded: false,
      style: AppTypography.body,
      dropdownColor: AppColors.bg900,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bg900,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border800)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border800)),
      ),
      items: [
        for (final m in ClaudePermissionMode.values)
          DropdownMenuItem(
              value: m,
              child: Text(_permLabel(l10n, m), style: AppTypography.body)),
      ],
      onChanged: _creating
          ? null
          : (v) {
              if (v == null) return;
              setState(
                  () => _claudeSettings = _claudeSettings.copyWith(permissionMode: v));
            },
    );
  }

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChange) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.body),
              Text(subtitle, style: AppTypography.meta),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: _creating ? null : onChange,
          activeTrackColor: AppColors.accent400,
        ),
      ]),
    );
  }

  Future<void> _saveAsTemplate() async {
    final name = _effectiveName;
    final prompt = _inputCtl.text.trim();
    if (prompt.isEmpty) return;
    final agentId = _primaryCli.id;
    final wd = _workspaceCtl.text.trim();
    widget.onSaveTemplate?.call(name, agentId, wd.isEmpty ? null : wd, prompt);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "$name" saved'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _footer(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (widget.onSaveTemplate != null && _inputCtl.text.trim().isNotEmpty)
            Tooltip(
              message: 'Save current task as a reusable template (⌘K to launch)',
              waitDuration: const Duration(milliseconds: 400),
              child: TextButton.icon(
                onPressed: _creating ? null : _saveAsTemplate,
                icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                label: const Text('Save template'),
                style: TextButton.styleFrom(foregroundColor: AppColors.text400),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _creating ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.text400),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _creating ? null : _onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent400,
              foregroundColor: AppColors.bg950,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bg950))
                : Text(_isMulti
                    ? l10n.dispatchToAgents(widget.clis.length)
                    : l10n.createAndRun),
          ),
        ]),
      );
}
