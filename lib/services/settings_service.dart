import 'package:shared_preferences/shared_preferences.dart';

/// Service for app-level settings via SharedPreferences.
///
/// This is the simplest key-value storage tier, suitable for:
/// - UI preferences (theme, window size, sidebar state)
/// - Last detection timestamp
/// - Feature flags
class SettingsService {
  SettingsService._();

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError('SettingsService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // --- Last detection time ---
  static DateTime? get lastDetectionTime {
    final ms = _p.getInt('last_detection_time');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastDetectionTime(DateTime time) async {
    await _p.setInt('last_detection_time', time.millisecondsSinceEpoch);
  }

  // --- Window state (macOS) ---
  static double? get windowWidth => _p.getDouble('window_width');
  static double? get windowHeight => _p.getDouble('window_height');
  static double? get windowX => _p.getDouble('window_x');
  static double? get windowY => _p.getDouble('window_y');
  static bool? get windowMaximized => _p.getBool('window_maximized');

  static Future<void> saveWindowState({
    double? width,
    double? height,
    double? x,
    double? y,
    bool? maximized,
  }) async {
    if (width != null) await _p.setDouble('window_width', width);
    if (height != null) await _p.setDouble('window_height', height);
    if (x != null) await _p.setDouble('window_x', x);
    if (y != null) await _p.setDouble('window_y', y);
    if (maximized != null) await _p.setBool('window_maximized', maximized);
  }

  // --- Sidebar split (resizable left panel) ---
  static double? get sidebarWidth => _p.getDouble('sidebar_width');
  static Future<void> setSidebarWidth(double width) async {
    await _p.setDouble('sidebar_width', width);
  }

  /// Height of the agent-list section above the task panel in the sidebar.
  static double? get agentSectionHeight => _p.getDouble('agent_section_height');
  static Future<void> setAgentSectionHeight(double height) async {
    await _p.setDouble('agent_section_height', height);
  }

  // --- Terminal font size ---
  static double get terminalFontSize =>
      _p.getDouble('terminal_font_size') ?? 13.0;
  static Future<void> setTerminalFontSize(double size) async {
    await _p.setDouble('terminal_font_size', size);
  }

  // --- Notifications ---
  static bool get notificationsEnabled =>
      _p.getBool('notifications_enabled') ?? true;
  static Future<void> setNotificationsEnabled(bool value) async {
    await _p.setBool('notifications_enabled', value);
  }

  // --- Claude CLI path override ---
  static String? get claudeCliPath => _p.getString('claude_cli_path');
  static Future<void> setClaudeCliPath(String? path) async {
    if (path == null || path.trim().isEmpty) {
      await _p.remove('claude_cli_path');
    } else {
      await _p.setString('claude_cli_path', path.trim());
    }
  }

  // --- Theme ---
  static String get themeMode => _p.getString('theme_mode') ?? 'system';
  static Future<void> setThemeMode(String mode) async {
    await _p.setString('theme_mode', mode);
  }

  // --- Hidden agents ---
  // Built-in CLIs the user chose to hide from the sidebar list (custom CLIs are
  // removed outright instead). Stored as a list of agent ids.
  static Set<String> get hiddenAgentIds =>
      (_p.getStringList('hidden_agent_ids') ?? const []).toSet();

  static Future<void> setHiddenAgentIds(Set<String> ids) async {
    await _p.setStringList('hidden_agent_ids', ids.toList());
  }

  // --- Per-CLI unsupported launch flags ---
  // Flags a given CLI's installed version rejected at launch (e.g. an older
  // `claude` that doesn't know `--effort`). Once recorded, they're stripped from
  // future launches up-front so the unknown-option failure never recurs.
  static List<String> deniedFlagsFor(String cliId) =>
      _p.getStringList('denied_flags_$cliId') ?? const [];

  /// Record [flag] as unsupported for [cliId]. Returns true if it was newly
  /// added (false if already known).
  static Future<bool> addDeniedFlag(String cliId, String flag) async {
    final current = deniedFlagsFor(cliId);
    if (current.contains(flag)) return false;
    await _p.setStringList('denied_flags_$cliId', [...current, flag]);
    return true;
  }

  /// Clear all recorded unsupported flags for [cliId] (e.g. after a CLI update).
  static Future<void> clearDeniedFlags(String cliId) async {
    await _p.remove('denied_flags_$cliId');
  }

  // --- Workspace bookmarks ---
  // Each entry stored as "name\tpath" (tab-separated).
  static List<({String name, String path})> get workspaceBookmarks {
    final raw = _p.getStringList('workspace_bookmarks') ?? [];
    return raw.expand<({String name, String path})>((s) {
      final idx = s.indexOf('\t');
      if (idx < 0) return [];
      return [(name: s.substring(0, idx), path: s.substring(idx + 1))];
    }).toList();
  }

  static Future<void> setWorkspaceBookmarks(
      List<({String name, String path})> bookmarks) async {
    await _p.setStringList(
      'workspace_bookmarks',
      bookmarks.map((b) => '${b.name}\t${b.path}').toList(),
    );
  }

  // --- Prompt templates ---
  // Each entry stored as "name\ttext" (tab-separated).
  static const List<String> _defaultPromptTemplates = [
    'Review code\tPlease review this code and identify any bugs, issues, or improvements.',
    'Write tests\tWrite comprehensive unit tests for the code above.',
    'Explain this\tPlease explain what this code does in simple terms.',
    'Fix the bug\tThere is a bug in the code above. Please identify and fix it.',
    'Refactor\tPlease refactor this code to be cleaner and follow best practices.',
  ];

  static List<({String name, String text})> get promptTemplates {
    final raw = _p.getStringList('prompt_templates') ?? _defaultPromptTemplates;
    return raw.expand<({String name, String text})>((s) {
      final idx = s.indexOf('\t');
      if (idx < 0) return [];
      return [(name: s.substring(0, idx), text: s.substring(idx + 1))];
    }).toList();
  }

  static Future<void> setPromptTemplates(
      List<({String name, String text})> templates) async {
    await _p.setStringList(
      'prompt_templates',
      templates.map((t) => '${t.name}\t${t.text}').toList(),
    );
  }

  // --- Watchdog (auto-retry failed sessions) ---
  static bool get watchdogEnabled =>
      _p.getBool('watchdog_enabled') ?? false;
  static Future<void> setWatchdogEnabled(bool value) async {
    await _p.setBool('watchdog_enabled', value);
  }

  /// Maximum number of automatic retries when a session exits with an error.
  static int get watchdogMaxRetries =>
      _p.getInt('watchdog_max_retries') ?? 2;
  static Future<void> setWatchdogMaxRetries(int value) async {
    await _p.setInt('watchdog_max_retries', value.clamp(1, 5));
  }

  /// Minimum seconds a session must run before a retry is attempted.
  /// Prevents retry-loops for sessions that crash immediately (bad binary, etc.).
  static int get watchdogMinRunSeconds =>
      _p.getInt('watchdog_min_run_seconds') ?? 5;
  static Future<void> setWatchdogMinRunSeconds(int value) async {
    await _p.setInt('watchdog_min_run_seconds', value.clamp(0, 60));
  }

  // --- Pinned sessions ---
  static Set<int> get pinnedSessionIds {
    final list = _p.getStringList('pinned_session_ids') ?? [];
    return list
        .map((s) => int.tryParse(s) ?? -1)
        .where((i) => i >= 0)
        .toSet();
  }

  static Future<void> setPinnedSessionIds(Set<int> ids) async {
    await _p.setStringList(
        'pinned_session_ids', ids.map((i) => i.toString()).toList());
  }
}
