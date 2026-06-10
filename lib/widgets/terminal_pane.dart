import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../l10n/app_localizations.dart';
import '../services/attachment_service.dart';
import '../services/process_monitor_service.dart';
import '../services/settings_service.dart';
import '../services/terminal_sessions_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_terminal_theme.dart';
import '../theme/app_typography.dart';
import 'attachment_strip.dart';
import 'prompt_templates_dialog.dart';
import 'quick_commands_bar.dart';
import 'task_panel.dart' show statusDotColor;

// ---------------------------------------------------------------------------
// Terminal search helpers
// ---------------------------------------------------------------------------

/// Scans every line in the terminal buffer for [query] (case-insensitive)
/// and returns a list of [CellOffset] pairs (begin, end) for every match.
List<(CellOffset, CellOffset)> _searchBuffer(Terminal terminal, String query) {
  if (query.isEmpty) return [];
  final lower = query.toLowerCase();
  final result = <(CellOffset, CellOffset)>[];
  final lines = terminal.buffer.lines;
  for (int y = 0; y < lines.length; y++) {
    final text = lines[y].getText().toLowerCase();
    int start = 0;
    while (true) {
      final idx = text.indexOf(lower, start);
      if (idx == -1) break;
      result.add((CellOffset(idx, y), CellOffset(idx + lower.length, y)));
      start = idx + 1;
    }
  }
  return result;
}

/// Right-hand terminal area of the single-page layout.
///
/// Cmd+= / Cmd++ increases font size; Cmd+- decreases; Cmd+0 resets.
/// Font size is persisted via [SettingsService].
class TerminalPane extends StatefulWidget {
  final TerminalSessionsController terminals;
  final void Function(ActiveTerminal)? onFollowUp;

  const TerminalPane({
    super.key,
    required this.terminals,
    this.onFollowUp,
  });

  static const double _minFontSize = 10;
  static const double _maxFontSize = 22;
  static const double _step = 1;

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  late double _fontSize;
  late final bool Function(KeyEvent) _keyHandler;

  // --- Split view state ---
  int? _splitId; // sessionId of the secondary (right) terminal; null = no split

  // --- Drag & drop state ---
  bool _dragHover = false;

  // --- Scroll state ---
  // One ScrollController per session so each tab remembers its scroll offset.
  final Map<int, ScrollController> _scrollControllers = {};
  bool _atBottom = true;

  // --- Search state ---
  bool _searchOpen = false;
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<TerminalHighlight> _highlights = [];
  int _hitIndex = 0;
  int _hitCount = 0;

  // --- Broadcast state ---
  bool _broadcastOpen = false;
  final TextEditingController _broadcastCtl = TextEditingController();
  final FocusNode _broadcastFocus = FocusNode();

  // --- Process stats ---
  Map<int, ProcessStats> _processStats = {};
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _fontSize = SettingsService.terminalFontSize;
    _keyHandler = _handleKey;
    HardwareKeyboard.instance.addHandler(_keyHandler);
    _searchCtl.addListener(_runSearch);
    widget.terminals.addListener(_onTerminalsChanged);
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollStats());
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    widget.terminals.removeListener(_onTerminalsChanged);
    for (final sc in _scrollControllers.values) {
      sc.dispose();
    }
    _searchCtl.dispose();
    _searchFocus.dispose();
    _broadcastCtl.dispose();
    _broadcastFocus.dispose();
    _clearHighlights();
    super.dispose();
  }

  Future<void> _pollStats() async {
    final pids = widget.terminals.sessionPids;
    if (pids.isEmpty) {
      if (_processStats.isNotEmpty && mounted) {
        setState(() => _processStats = {});
      }
      return;
    }
    final stats = await ProcessMonitorService.poll(pids);
    if (mounted) setState(() => _processStats = stats);
  }

  void _onTerminalsChanged() {
    // Remove scroll controllers for sessions that were closed.
    final openIds =
        widget.terminals.openTerminals.map((t) => t.sessionId).toSet();
    _scrollControllers.keys
        .where((id) => !openIds.contains(id))
        .toList()
        .forEach((id) {
      _scrollControllers.remove(id)?.dispose();
    });
    // Auto-scroll to bottom on new output when already at bottom.
    final active = widget.terminals.active;
    if (active != null && _atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  ScrollController _scrollControllerFor(int sessionId) {
    return _scrollControllers.putIfAbsent(sessionId, () {
      final sc = ScrollController();
      sc.addListener(() {
        if (!sc.hasClients) return;
        final atBottom =
            sc.position.pixels >= sc.position.maxScrollExtent - 4;
        if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
      });
      return sc;
    });
  }

  void _jumpToBottom() {
    final active = widget.terminals.active;
    if (active == null) return;
    final sc = _scrollControllers[active.sessionId];
    if (sc == null || !sc.hasClients) return;
    sc.jumpTo(sc.position.maxScrollExtent);
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    // Esc closes search
    if (event.logicalKey == LogicalKeyboardKey.escape && _searchOpen) {
      _closeSearch();
      return true;
    }
    if (!meta) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.numpadAdd:
        _adjustFontSize(TerminalPane._step);
        return true;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        _adjustFontSize(-TerminalPane._step);
        return true;
      case LogicalKeyboardKey.digit0:
      case LogicalKeyboardKey.numpad0:
        _resetFontSize();
        return true;
      case LogicalKeyboardKey.keyF:
        _toggleSearch();
        return true;
      case LogicalKeyboardKey.keyS:
        _exportOutput();
        return true;
      case LogicalKeyboardKey.keyV:
        // Image-aware paste: when the clipboard holds an image, save it to
        // a temp PNG and type the path; otherwise paste text as usual.
        _pasteSmart();
        return true;
      default:
        return false;
    }
  }

  // --- Smart paste (image or text) ---

  Future<void> _pasteSmart() async {
    final active = widget.terminals.active;
    if (active == null) return;

    // Copied files first (attaches the ORIGINAL file — reading the image
    // bytes for a Finder-copied file would yield its icon), then raw image
    // bytes (screenshots), then plain text.
    final paths = await AttachmentService.clipboardPaths();
    if (paths.isNotEmpty) {
      _addPaths(paths);
      return;
    }
    if (!active.running) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) active.sendText(text);
  }

  /// Queue paths into the attachment strip; they are auto-sent with the
  /// next Enter (or via the strip's Insert button). No toast — the
  /// thumbnail appearing in the strip IS the feedback.
  void _addPaths(Iterable<String> paths) {
    final active = widget.terminals.active;
    if (active == null) return;
    final list = paths.where((p) => p.isNotEmpty).toList();
    if (list.isEmpty) return;
    widget.terminals.addAttachments(active.sessionId, list);
  }

  Future<void> _pickAndAttach() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    _addPaths(result.files
        .map((f) => f.path)
        .whereType<String>());
  }


  // --- Search methods ---

  // --- Close with confirmation ---

  Future<void> _closeWithConfirm(int sessionId) async {
    final term = widget.terminals.openTerminals
        .firstWhere((t) => t.sessionId == sessionId,
            orElse: () => widget.terminals.active!);
    if (term.running) {
      final l10n = AppLocalizations.of(context)!;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bg800,
          title: Text(l10n.closeTerminal,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text200)),
          content: Text(
              l10n.taskStillRunningClose,
              style: const TextStyle(fontSize: 14, color: AppColors.text400)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.text400),
              child: Text(l10n.keepRunning),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.red400),
              child: Text(l10n.stopAndClose),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    widget.terminals.close(sessionId);
  }

  // --- Split view ---

  void _toggleSplit(List<ActiveTerminal> open, ActiveTerminal active) {
    if (_splitId != null) {
      setState(() => _splitId = null);
      return;
    }
    // Pick the first terminal that isn't already the active one.
    final other = open.firstWhere(
      (t) => t.sessionId != active.sessionId,
      orElse: () => open.first,
    );
    setState(() => _splitId = other.sessionId);
  }

  // --- Broadcast ---

  void _toggleBroadcast() {
    setState(() => _broadcastOpen = !_broadcastOpen);
    if (_broadcastOpen) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _broadcastFocus.requestFocus());
    }
  }

  void _sendBroadcast() {
    final text = _broadcastCtl.text.trim();
    if (text.isEmpty) return;
    widget.terminals.broadcast(text);
    _broadcastCtl.clear();
    // Keep the bar open for follow-ups; focus stays in the field.
    _broadcastFocus.requestFocus();
  }

  // --- Export ---

  Future<void> _exportOutput() async {
    final active = widget.terminals.active;
    if (active == null) return;

    // Collect all lines from the terminal buffer as plain text.
    final buf = active.terminal.buffer;
    final sb = StringBuffer();
    for (int i = 0; i < buf.lines.length; i++) {
      sb.writeln(buf.lines[i].getText().trimRight());
    }
    final text = sb.toString();

    // Write to Desktop/agentdock-<name>-<timestamp>.txt
    final home = Platform.environment['HOME'] ?? '';
    final safe = active.sessionName.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$home/Desktop/agentdock-$safe-$ts.txt';

    try {
      await File(path).writeAsString(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!
              .savedToDesktop(path.split('/').last)),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.bg800,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.exportFailed('$e')),
          backgroundColor: AppColors.red500,
        ));
      }
    }
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
    } else {
      setState(() => _searchOpen = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  void _closeSearch() {
    _clearHighlights();
    setState(() {
      _searchOpen = false;
      _hitCount = 0;
      _hitIndex = 0;
    });
    _searchCtl.clear();
  }

  void _clearHighlights() {
    for (final h in _highlights) {
      h.dispose();
    }
    _highlights = [];
  }

  void _runSearch() {
    final active = widget.terminals.active;
    if (active == null) return;
    _clearHighlights();
    final query = _searchCtl.text;
    if (query.isEmpty) {
      setState(() { _hitCount = 0; _hitIndex = 0; });
      return;
    }
    final matches = _searchBuffer(active.terminal, query);
    final buf = active.terminal.buffer;
    _highlights = matches.map((pair) {
      final (begin, end) = pair;
      return active.viewController.highlight(
        p1: buf.createAnchorFromOffset(begin),
        p2: buf.createAnchorFromOffset(end),
        color: AppTerminalTheme.dark.searchHitBackground.withAlpha(153),
      );
    }).toList();
    setState(() {
      _hitCount = matches.length;
      _hitIndex = matches.isEmpty ? 0 : 1;
    });
  }

  void _nextHit() {
    if (_hitCount == 0) return;
    setState(() => _hitIndex = (_hitIndex % _hitCount) + 1);
  }

  void _prevHit() {
    if (_hitCount == 0) return;
    setState(() => _hitIndex = _hitIndex <= 1 ? _hitCount : _hitIndex - 1);
  }

  // --- Font size methods ---

  void _adjustFontSize(double delta) {
    final next = (_fontSize + delta).clamp(
        TerminalPane._minFontSize, TerminalPane._maxFontSize);
    if (next == _fontSize) return;
    setState(() => _fontSize = next);
    SettingsService.setTerminalFontSize(next);
  }

  void _resetFontSize() {
    const def = 13.0;
    if (_fontSize == def) return;
    setState(() => _fontSize = def);
    SettingsService.setTerminalFontSize(def);
  }

  Widget _buildSplitView(
    List<ActiveTerminal> open,
    ActiveTerminal active,
    TerminalStyle textStyle,
    AppLocalizations l10n,
  ) {
    final splitTerm = open.firstWhere(
      (t) => t.sessionId == _splitId,
      orElse: () {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => setState(() => _splitId = null));
        return active;
      },
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardGap),
      child: Row(
        children: [
          Expanded(child: _terminalCard(active, textStyle)),
          Container(width: 6, color: AppColors.border800),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: DropdownButtonFormField<int>(
                    initialValue: splitTerm.sessionId,
                    isExpanded: true,
                    style: AppTypography.bodySmall,
                    dropdownColor: AppColors.bg900,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppColors.bg800,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.border700)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.border700)),
                    ),
                    items: open
                        .map((t) => DropdownMenuItem(
                              value: t.sessionId,
                              child: Row(children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusDotColor(t.effectiveStatus),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(t.sessionName,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall),
                                ),
                              ]),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) setState(() => _splitId = id);
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(child: _terminalCard(splitTerm, textStyle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _terminalCard(ActiveTerminal term, TerminalStyle textStyle) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.bg950,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
              color: AppColors.border800, width: AppSpacing.cardBorderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: TerminalView(
          term.terminal,
          key: ValueKey('split-${term.sessionId}'),
          controller: term.viewController,
          scrollController: _scrollControllerFor(term.sessionId),
          theme: AppTerminalTheme.dark,
          textStyle: textStyle,
          padding: const EdgeInsets.all(AppSpacing.cardGap),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = AppTerminalTheme.textStyle.copyWith(fontSize: _fontSize);

    return AnimatedBuilder(
      animation: widget.terminals,
      builder: (context, _) {
        final open = widget.terminals.openTerminals;
        final active = widget.terminals.active;

        if (open.isEmpty || active == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal,
                    size: AppSpacing.iconXl, color: AppColors.text500),
                const SizedBox(height: 12),
                Text(l10n.noOpenTerminal, style: AppTypography.body),
                const SizedBox(height: 8),
                Text(l10n.cmdNHint,
                    style: AppTypography.meta),
              ],
            ),
          );
        }

        return Column(
          children: [
            // --- Tab strip + font-size indicator ---
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.cardGap, 8, AppSpacing.cardGap, 0),
                      buildDefaultDragHandles: false,
                      itemCount: open.length,
                      onReorder: widget.terminals.reorderTab,
                      itemBuilder: (context, index) {
                        final term = open[index];
                        return ReorderableDragStartListener(
                          key: ValueKey(term.sessionId),
                          index: index,
                          child: _TerminalTab(
                            term: term,
                            isActive: term.sessionId == active.sessionId,
                            closeTooltip: l10n.closeTerminal,
                            processStats: _processStats[term.sessionId],
                            onTap: () =>
                                widget.terminals.setActive(term.sessionId),
                            onClose: () =>
                                _closeWithConfirm(term.sessionId),
                          ),
                        );
                      },
                    ),
                  ),
                  // Font-size hint (only when non-default)
                  if (_fontSize != 13.0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${_fontSize.toInt()}px',
                        style: AppTypography.meta,
                      ),
                    ),
                  // Prompt templates button
                  if (active.running)
                    Tooltip(
                      message: l10n.promptTemplatesTooltip,
                      child: GestureDetector(
                        onTap: () => PromptTemplatesDialog.show(
                          context,
                          (text) => active.sendText(text),
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.bolt_outlined,
                              size: 16,
                              color: AppColors.text500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Attach files button
                  Tooltip(
                    message: l10n.attachFilesTooltip,
                    child: GestureDetector(
                      onTap: _pickAndAttach,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.attach_file,
                            size: 16,
                            color: AppColors.text500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Broadcast button (only when 2+ terminals are running)
                  if (widget.terminals.runningTerminals.length >= 2)
                    Tooltip(
                      message: _broadcastOpen
                          ? l10n.closeBroadcast
                          : l10n.broadcastTooltip,
                      child: GestureDetector(
                        onTap: _toggleBroadcast,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.campaign_outlined,
                              size: 17,
                              color: _broadcastOpen
                                  ? AppColors.accent400
                                  : AppColors.text500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Split-view toggle button (only when 2+ terminals open)
                  if (open.length >= 2)
                    Tooltip(
                      message: _splitId != null
                          ? l10n.exitSplitView
                          : l10n.splitView,
                      child: GestureDetector(
                        onTap: () => _toggleSplit(open, active),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                            child: Icon(
                              _splitId != null
                                  ? Icons.close_fullscreen
                                  : Icons.view_column_outlined,
                              size: 16,
                              color: _splitId != null
                                  ? AppColors.accent400
                                  : AppColors.text500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // --- Terminal area (single or split), drop target for files ---
            Expanded(
              child: DropTarget(
                onDragEntered: (_) => setState(() => _dragHover = true),
                onDragExited: (_) => setState(() => _dragHover = false),
                onDragDone: (details) {
                  setState(() => _dragHover = false);
                  _addPaths(details.files.map((f) => f.path));
                },
                child: Container(
                  decoration: _dragHover
                      ? BoxDecoration(
                          border: Border.all(
                              color: AppColors.accent400, width: 2),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius),
                        )
                      : null,
                  child: _splitId != null
                  ? _buildSplitView(open, active, textStyle, l10n)
                  : Padding(
                padding: const EdgeInsets.all(AppSpacing.cardGap),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg950,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(
                          color: AppColors.border800,
                          width: AppSpacing.cardBorderWidth,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TerminalView(
                        active.terminal,
                        key: ValueKey(active.sessionId),
                        controller: active.viewController,
                        scrollController:
                            _scrollControllerFor(active.sessionId),
                        autofocus: !_searchOpen,
                        theme: AppTerminalTheme.dark,
                        textStyle: textStyle,
                        padding: const EdgeInsets.all(AppSpacing.cardGap),
                      ),
                    ),
                    // Scroll-to-bottom FAB
                    if (!_atBottom)
                      Positioned(
                        right: 12,
                        bottom: _searchOpen ? 50 : 12,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _atBottom = true);
                            _jumpToBottom();
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.bg800,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.border700),
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: AppColors.text400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_searchOpen)
                      Positioned(
                        top: 8,
                        right: 12,
                        child: _SearchBar(
                          controller: _searchCtl,
                          focusNode: _searchFocus,
                          hitIndex: _hitIndex,
                          hitCount: _hitCount,
                          onNext: _nextHit,
                          onPrev: _prevHit,
                          onClose: _closeSearch,
                        ),
                      ),
                  ],
                ),
              ),
                ),  // end Container (drag highlight)
              ),  // end DropTarget
            ),  // end Expanded

            // --- Broadcast input bar (sends to ALL running terminals) ---
            if (_broadcastOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardGap,
                  0,
                  AppSpacing.cardGap,
                  AppSpacing.cardGap,
                ),
                child: _BroadcastBar(
                  controller: _broadcastCtl,
                  focusNode: _broadcastFocus,
                  targetCount: widget.terminals.runningTerminals.length,
                  onSend: _sendBroadcast,
                  onClose: _toggleBroadcast,
                ),
              ),

            // --- Quick slash-command chips (running terminals only) ---
            if (active.running)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardGap,
                  0,
                  AppSpacing.cardGap,
                  AppSpacing.cardGap,
                ),
                child: QuickCommandsBar(
                  onSend: (text) => active.sendText(text),
                ),
              ),

            // --- Pending attachment strip ---
            if (active.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardGap,
                  0,
                  AppSpacing.cardGap,
                  AppSpacing.cardGap,
                ),
                child: AttachmentStrip(
                  attachments: active.attachments,
                  running: active.running,
                  onPreview: (p) => showAttachmentPreview(context, p),
                  onRemove: (i) => widget.terminals
                      .removeAttachmentAt(active.sessionId, i),
                  onClear: () =>
                      widget.terminals.clearAttachments(active.sessionId),
                  onInsert: () =>
                      widget.terminals.insertAttachmentsNow(active.sessionId),
                ),
              ),

            // --- Exited status bar ---
            if (!active.running && active.exitCode != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardGap,
                  0,
                  AppSpacing.cardGap,
                  AppSpacing.cardGap,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bg800,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(
                      color: AppColors.border700,
                      width: AppSpacing.cardBorderWidth,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        active.exitCode == 0
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: AppSpacing.iconMd,
                        color: active.exitCode == 0
                            ? AppColors.emerald500
                            : AppColors.red400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.processExited(active.exitCode ?? -1),
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      if (widget.onFollowUp != null) ...[
                        OutlinedButton.icon(
                          onPressed: () => widget.onFollowUp!(active),
                          icon: const Icon(Icons.add_task, size: 16),
                          label: Text(l10n.followUp),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent400,
                            side: const BorderSide(
                                color: AppColors.accent400),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.terminals.relaunch(active.sessionId),
                        icon: const Icon(Icons.replay, size: 16),
                        label: Text(l10n.relaunchSession),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int hitIndex;
  final int hitCount;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hitIndex,
    required this.hitCount,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bg800,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(color: AppColors.accent400, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(102),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 14, color: AppColors.text500),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text200),
                cursorColor: AppColors.accent400,
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)!.searchInTerminal,
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.text500),
                ),
                onSubmitted: (_) => onNext(),
              ),
            ),
            if (hitCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$hitIndex / $hitCount',
                  style: AppTypography.meta,
                ),
              )
            else if (controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(AppLocalizations.of(context)!.noResults,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.red400)),
              ),
            _iconBtn(Icons.keyboard_arrow_up, onPrev),
            _iconBtn(Icons.keyboard_arrow_down, onNext),
            _iconBtn(Icons.close, onClose),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(icon, size: 16, color: AppColors.text400),
          ),
        ),
      );
}

String _folderName(String? path) {
  if (path == null || path.isEmpty) return '';
  final trimmed = path.trimRight().replaceAll(RegExp(r'/+$'), '');
  final slash = trimmed.lastIndexOf('/');
  return slash == -1 ? trimmed : trimmed.substring(slash + 1);
}

class _TerminalTab extends StatefulWidget {
  final ActiveTerminal term;
  final bool isActive;
  final String closeTooltip;
  final ProcessStats? processStats;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TerminalTab({
    required this.term,
    required this.isActive,
    required this.closeTooltip,
    this.processStats,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<_TerminalTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final term = widget.term;
    final bg = widget.isActive
        ? AppColors.bg800
        : _hovered
            ? AppColors.surface50
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppSpacing.fastTransition,
          margin: const EdgeInsets.only(right: AppSpacing.sectionGap),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.inputRadius),
            ),
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? AppColors.accent400
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusDotColor(term.effectiveStatus),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      term.sessionName,
                      style: widget.isActive || term.hasUnread
                          ? AppTypography.label
                              .copyWith(color: AppColors.text200)
                          : AppTypography.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Builder(builder: (context) {
                      final folder = _folderName(term.workingDirectory);
                      final stats = widget.processStats;
                      final showStats = term.running && stats != null;
                      if (folder.isEmpty && !showStats) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (folder.isNotEmpty)
                            Flexible(
                              child: Text(
                                folder,
                                style: AppTypography.meta.copyWith(
                                  fontSize: 9,
                                  color: widget.isActive
                                      ? AppColors.accent400
                                      : AppColors.text500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (folder.isNotEmpty && showStats)
                            Text(' · ',
                                style: AppTypography.meta.copyWith(
                                    fontSize: 9, color: AppColors.text500)),
                          if (showStats)
                            Text(
                              '${stats.cpuLabel} ${stats.memLabel}',
                              style: AppTypography.mono.copyWith(
                                fontSize: 9,
                                color: AppColors.emerald500.withAlpha(200),
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              // Unread-output dot for background tabs
              if (term.hasUnread && !widget.isActive) ...[
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
              const SizedBox(width: 8),
              Tooltip(
                message: widget.closeTooltip,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(
                    Icons.close,
                    size: AppSpacing.iconSm,
                    color:
                        _hovered ? AppColors.text200 : AppColors.text500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline input bar that broadcasts a message to every running terminal.
///
/// Enter sends (bar stays open for follow-ups), Esc closes. The target
/// count is displayed so the user knows how many agents will receive it.
class _BroadcastBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int targetCount;
  final VoidCallback onSend;
  final VoidCallback onClose;

  const _BroadcastBar({
    required this.controller,
    required this.focusNode,
    required this.targetCount,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bg800,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.accent400),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined,
              size: 16, color: AppColors.accent400),
          const SizedBox(width: 8),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): onClose,
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppTypography.body,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)!.broadcastHint,
                  hintStyle: AppTypography.bodySmall,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppLocalizations.of(context)!.broadcastTargets(targetCount),
              style: AppTypography.meta
                  .copyWith(color: AppColors.accent400),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: const Icon(Icons.close,
                  size: 15, color: AppColors.text500),
            ),
          ),
        ],
      ),
    );
  }
}
