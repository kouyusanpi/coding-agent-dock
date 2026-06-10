// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Agent CLI Manager';

  @override
  String get agentOSCli => 'AgentDock';

  @override
  String get localEnvironments => 'Local Environments';

  @override
  String get daemonActive => 'Daemon Active';

  @override
  String get missing => 'Missing';

  @override
  String get detectingInstalled => 'Detecting Installed Agents';

  @override
  String get scanningEnvironments => 'Scanning local environments...';

  @override
  String get scan => 'Scan';

  @override
  String get rescan => 'Rescan';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get sessions => 'Sessions';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String get createSessionToStart => 'Create a new session to get started.';

  @override
  String get searchResults => 'Search Results';

  @override
  String get showingAllEnvironments =>
      'Showing matches across all environments.';

  @override
  String get selectPastSession => 'Select a past session or create a new one.';

  @override
  String initializeNewSession(String agentName) {
    return 'Initialize New $agentName Session';
  }

  @override
  String get statusRunning => 'Running';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusLaunched => 'Launched';

  @override
  String get statusCreated => 'Created';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get newSessionTitle => 'Initialize New Session';

  @override
  String get workspacePath => 'Workspace Path';

  @override
  String get workspaceHint => '~/projects/my-project';

  @override
  String get sessionName => 'Session Name';

  @override
  String get sessionNameHint => 'Refactor API router...';

  @override
  String get promptInput => 'Task Prompt';

  @override
  String get promptHint => 'Describe what you want the agent to do...';

  @override
  String get cancel => 'Cancel';

  @override
  String get createAndRun => 'Create & Run';

  @override
  String createFailed(String error) {
    return 'Failed to create session: $error';
  }

  @override
  String get workspace => 'Workspace';

  @override
  String get deleteSession => 'Delete Session';

  @override
  String deleteSessionConfirm(String name) {
    return 'Delete session \"$name\"? This cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String processExited(int code) {
    return 'Process exited (code $code). The conversation was saved and can be resumed.';
  }

  @override
  String get relaunchSession => 'Resume Session';

  @override
  String get tasksSection => 'TASKS';

  @override
  String get newTask => 'New Task';

  @override
  String runningCount(int count) {
    return '$count running';
  }

  @override
  String get noOpenTerminal => 'Select a task on the left to open its terminal';

  @override
  String get closeTerminal => 'Close terminal';

  @override
  String get searchTasks => 'Search tasks...';

  @override
  String get allAgents => 'All';

  @override
  String get searchHint => 'Search sessions, tags, or workspaces...';

  @override
  String get sessionSearchComing => 'Session search coming soon';

  @override
  String get tryDifferentSearch =>
      'Try a different search term or check local CLI paths.';

  @override
  String get addCustomAgent => 'Add Custom Agent';

  @override
  String get displayNameLabel => 'Display Name';

  @override
  String get displayNameHint => 'e.g. My Agent CLI';

  @override
  String get binaryLabel => 'Binary (command name or full path)';

  @override
  String get binaryHint => 'e.g. myagent or /usr/local/bin/myagent';

  @override
  String get browse => 'Browse…';

  @override
  String get versionFlagLabel => 'Version Flag';

  @override
  String get addAgentButton => 'Add Agent';

  @override
  String get nameAndBinaryRequired => 'Name and binary are required';

  @override
  String get agentAlreadyExists => 'An agent with this binary already exists';

  @override
  String get removeCustomAgent => 'Remove custom agent';

  @override
  String get hideAgent => 'Hide from list';

  @override
  String hiddenAgentsCount(int count) {
    return '$count hidden';
  }

  @override
  String get showAllAgents => 'Show all';

  @override
  String installAgentTitle(String name) {
    return 'Install $name';
  }

  @override
  String agentNotFound(String name) {
    return '$name was not found on your system.';
  }

  @override
  String get installWith => 'Install with:';

  @override
  String get afterInstallRescan =>
      'After installing, click the ↻ button to rescan.';

  @override
  String get close => 'Close';

  @override
  String get broadcastTooltip => 'Broadcast to all running agents';

  @override
  String get closeBroadcast => 'Close broadcast';

  @override
  String get broadcastHint => 'Send to all running agents…';

  @override
  String broadcastTargets(int count) {
    return '→ $count agents';
  }

  @override
  String get attachFilesTooltip =>
      'Attach files (or drag & drop / Cmd+V an image)';

  @override
  String get splitView => 'Split view';

  @override
  String get exitSplitView => 'Exit split view';

  @override
  String get newTaskHere => 'New task here';

  @override
  String get newTaskSameFolder => 'New task in same folder';

  @override
  String get sendToAgent => 'Send to agent';

  @override
  String get openInFinder => 'Open in Finder';

  @override
  String get copyPrompt => 'Copy prompt';

  @override
  String get copyOutput => 'Copy output';

  @override
  String get tapToCopyOutput => 'Tap to copy full output';

  @override
  String cliNotInstalled(String name) {
    return 'CLI $name is not installed or not found on this system. Run Scan to detect available CLIs.';
  }

  @override
  String get agentsLabel => 'Agents';

  @override
  String dispatchingToAgents(int count) {
    return 'Dispatching to $count agents simultaneously';
  }

  @override
  String dispatchToAgents(int count) {
    return 'Dispatch to $count Agents';
  }

  @override
  String get resetToAutoName => 'Reset to auto-name';

  @override
  String get claudeOptions => 'Claude Options';

  @override
  String get modelLabel => 'Model';

  @override
  String get thinkingLabel => 'Thinking';

  @override
  String get permissionsLabel => 'Permissions';

  @override
  String get skipAllPermissions => 'Skip All Permissions';

  @override
  String get nonInteractive => 'Non-interactive';

  @override
  String get nonInteractiveDesc => '--print, output and exit';

  @override
  String get quickSelect => 'Quick select';

  @override
  String get typeModelName => 'Or type any model API name';

  @override
  String get modelDefaultLabel => 'Default (Opus 4.8, 1M context)';

  @override
  String get modelSonnetLabel => 'Sonnet 4.6 — Best for everyday tasks';

  @override
  String get modelHaikuLabel => 'Haiku 4.5 — Fastest, quick answers';

  @override
  String get modelOpusPinned => 'Opus 4.8 pinned';

  @override
  String get modelSonnetPinned => 'Sonnet 4.6 pinned';

  @override
  String get effortLow => 'Low';

  @override
  String get effortMedium => 'Medium';

  @override
  String get effortHigh => 'High';

  @override
  String get effortXhigh => 'Extra High';

  @override
  String get effortMax => 'Maximum';

  @override
  String get permDefault => 'Default';

  @override
  String get permAcceptEdits => 'Accept Edits';

  @override
  String get permAuto => 'Auto';

  @override
  String get permBypass => 'Bypass All';

  @override
  String get permDontAsk => 'Don\'t Ask';

  @override
  String get permPlan => 'Plan Only';

  @override
  String get newTaskSubtitle => 'Create a new agent task';

  @override
  String get rescanAgents => 'Rescan Agents';

  @override
  String get rescanAgentsSubtitle => 'Re-detect installed CLI tools';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get openSettingsSubtitle => 'Font size, notifications, CLI path';

  @override
  String get paletteSearchHint =>
      'Search sessions, @agent filter, or run a command…';

  @override
  String get noResults => 'No results';

  @override
  String get settings => 'Settings';

  @override
  String get sectionTerminal => 'Terminal';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get fontSize => 'Font size';

  @override
  String get taskCompletionAlerts => 'Task completion alerts';

  @override
  String get taskCompletionAlertsDesc => 'Notify when a terminal task finishes';

  @override
  String get binaryPathOverride => 'Binary path override';

  @override
  String get binaryPathDesc =>
      'Leave blank to auto-detect (~/.local/bin/claude first)';

  @override
  String get taskStillRunningStop =>
      'This task is still running. Stop it and close?';

  @override
  String get taskStillRunningClose =>
      'This task is still running. Close and stop it?';

  @override
  String get keepRunning => 'Keep Running';

  @override
  String get stopAndClose => 'Stop & Close';

  @override
  String get cmdNHint => 'Cmd+N to create a new task';

  @override
  String savedToDesktop(String name) {
    return 'Saved to ~/Desktop/$name';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get followUp => 'Follow-up';

  @override
  String get clearFinishedSessions => 'Clear completed / failed sessions';

  @override
  String get insertPathsTooltip => 'Type all paths into the input now';

  @override
  String get terminalNotRunning => 'Terminal not running';

  @override
  String get insert => 'Insert';

  @override
  String get clearAllAttachments => 'Clear all attachments';

  @override
  String previewFailed(String error) {
    return 'Preview failed: $error';
  }

  @override
  String get searchInTerminal => 'Search…';

  @override
  String get pinSession => 'Pin to top';

  @override
  String get unpinSession => 'Unpin';

  @override
  String get relayToAll => 'Relay to all agents';

  @override
  String relayToAllSubtitle(int count) {
    return '$count other agents';
  }

  @override
  String get agentFound => 'Found';

  @override
  String get keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get shortcutsGlobal => 'Global';

  @override
  String get shortcutsTabs => 'Terminal Tabs';

  @override
  String get shortcutsTerminal => 'In Terminal';

  @override
  String get shortcutCommandPalette => 'Command Palette';

  @override
  String get shortcutNewTaskClipboard => 'New Task from Clipboard';

  @override
  String get shortcutNextTab => 'Next Tab';

  @override
  String get shortcutPrevTab => 'Previous Tab';

  @override
  String get shortcutJumpToTab => 'Jump to Tab 1–9';

  @override
  String get shortcutCloseTab => 'Close Tab';

  @override
  String get shortcutSearch => 'Search in Terminal';

  @override
  String get shortcutExport => 'Export Terminal';

  @override
  String get shortcutShowShortcuts => 'Keyboard Shortcuts';

  @override
  String get editNote => 'Edit Note';

  @override
  String get notePlaceholder => 'Add a note to this session...';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get save => 'Save';

  @override
  String get exportAsMarkdown => 'Export as Markdown';

  @override
  String get agentLabel => 'Agent';

  @override
  String get statusLabel => 'Status';

  @override
  String get workingDirectory => 'Working Directory';

  @override
  String get duration => 'Duration';

  @override
  String get inputPrompt => 'Task';

  @override
  String get notes => 'Notes';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortByName => 'A → Z';

  @override
  String get sortByDuration => 'Longest first';

  @override
  String get statsTitle => 'Session Statistics';

  @override
  String get statsAgent => 'Agent';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsDone => 'Done';

  @override
  String get statsFailed => 'Failed';

  @override
  String get statsAvgTime => 'Avg';

  @override
  String get statsTotalTime => 'Total compute';

  @override
  String get noStatsYet => 'No sessions recorded yet.';

  @override
  String get tapToViewOutput => 'Tap to view full output';

  @override
  String get viewFullOutput => 'Full Output';

  @override
  String exitCode(int code) {
    return 'exit $code';
  }

  @override
  String get retryAllFailed => 'Retry failed';

  @override
  String get retrySession => 'Retry this session';

  @override
  String get cloneSession => 'Clone Session';

  @override
  String get addBookmark => 'Save as bookmark';

  @override
  String get bookmarkNameHint => 'e.g. My Flutter App';

  @override
  String get bookmarkSaved => 'Bookmark saved';

  @override
  String get setColor => 'Set color label';

  @override
  String get clearColor => 'Clear color';

  @override
  String get groupByProject => 'Group by project';

  @override
  String get groupOther => 'Other';

  @override
  String get promptTemplatesTooltip => 'Prompt templates';

  @override
  String get sharedMemoryTooltip => 'Shared project memory';

  @override
  String get sharedMemoryTitle => 'Shared project memory';

  @override
  String get sharedMemoryDescription =>
      'Shared with every agent in this project — synced into CLAUDE.md, AGENTS.md and GEMINI.md when a session launches.';

  @override
  String get sharedMemoryPlaceholder =>
      'Conventions, context and notes to share with every agent in this project…';

  @override
  String broadcastTitle(int count) {
    return 'Broadcast to $count running agents';
  }

  @override
  String get broadcastDescription =>
      'Sends your message directly to every running agent\'s stdin — all agents receive it simultaneously.';

  @override
  String get broadcastPlaceholder =>
      'Type a message or prompt to broadcast to all running agents…';

  @override
  String get broadcastSend => 'Send';

  @override
  String get injectMessageTooltip => 'Send to this agent';

  @override
  String injectMessageTitle(String agentName) {
    return 'Send to $agentName';
  }

  @override
  String get injectMessageDescription =>
      'Sends directly to this agent\'s stdin.';

  @override
  String get shortcutsAgents => 'Agents';

  @override
  String get shortcutBroadcast => 'Broadcast to all running agents';

  @override
  String get shortcutInjectActive => 'Send message to active agent';

  @override
  String get runOnAllAgents => 'Run on all agents';

  @override
  String runOnAllAgentsSubtitle(int count) {
    return 'Create a session for each of the $count detected agents';
  }

  @override
  String commandBroadcastSubtitle(int count) {
    return '⇧⌘B · Send a prompt to all $count running agents';
  }

  @override
  String get scanning => 'Scanning…';

  @override
  String get lastScannedJustNow => 'Last scanned: just now';

  @override
  String lastScannedMinutesAgo(int minutes) {
    return 'Last scanned: ${minutes}m ago';
  }

  @override
  String lastScannedHoursAgo(int hours) {
    return 'Last scanned: ${hours}h ago';
  }

  @override
  String lastScannedDaysAgo(int days) {
    return 'Last scanned: ${days}d ago';
  }

  @override
  String clusterRunTitle(int count) {
    return 'Cluster Run · $count agents';
  }

  @override
  String get workflowTemplates => 'Workflow Templates';

  @override
  String get workflowNew => 'New Workflow';

  @override
  String get workflowEdit => 'Edit';

  @override
  String get workflowDelete => 'Delete';

  @override
  String get workflowLaunch => 'Launch';

  @override
  String get workflowImport => 'Import';

  @override
  String get workflowExport => 'Export';

  @override
  String get workflowNoTemplates => 'No workflow templates yet.';

  @override
  String get workflowCreateHint =>
      'Create one to define multi-agent DAG workflows.';

  @override
  String get workflowDeleteConfirm => 'Cannot be undone.';

  @override
  String workflowDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String workflowStats(int agents, int nodes, int edges) {
    return '$agents agents, $nodes nodes, $edges edges';
  }

  @override
  String get workflowEditorTitle => 'Workflow Editor';

  @override
  String get workflowName => 'Workflow Name';

  @override
  String get workflowDescription => 'Description';

  @override
  String get workflowWorkingDir => 'Working Directory';

  @override
  String get workflowNodes => 'Nodes';

  @override
  String get workflowEdges => 'Edges';

  @override
  String get workflowAddNode => 'Add Node';

  @override
  String get workflowAddEdge => 'Add Edge';

  @override
  String get workflowNodeName => 'Node Name';

  @override
  String get workflowNodeAgent => 'Agent';

  @override
  String get workflowNodePrompt => 'Prompt Template';

  @override
  String get workflowEdgeFrom => 'From';

  @override
  String get workflowEdgeTo => 'To';

  @override
  String get workflowEdgeCondition => 'Condition';

  @override
  String get workflowRunTitle => 'Workflow Run';

  @override
  String get workflowRunCancel => 'Cancel Workflow';

  @override
  String get workflowRunRetry => 'Retry';

  @override
  String workflowRunProgress(int completed, int total) {
    return '$completed/$total nodes completed';
  }

  @override
  String get shortcutWorkflow => 'Open Workflow Templates';

  @override
  String get customArgsLabel => 'Custom launch arguments';

  @override
  String get customArgsDesc => 'Override the auto-generated flags';

  @override
  String get customArgsHint => 'e.g. --model sonnet --permission-mode plan';

  @override
  String get customArgsEmptyHint =>
      'Leave empty to launch the bare command with no flags.';
}
