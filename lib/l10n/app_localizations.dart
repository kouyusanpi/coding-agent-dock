import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The title of the application shown in the app bar and window chrome
  ///
  /// In en, this message translates to:
  /// **'Agent CLI Manager'**
  String get appTitle;

  /// Brand name shown in the sidebar header
  ///
  /// In en, this message translates to:
  /// **'AgentDock'**
  String get agentOSCli;

  /// Sidebar section heading for locally detected CLI environments
  ///
  /// In en, this message translates to:
  /// **'Local Environments'**
  String get localEnvironments;

  /// Status badge indicating the background daemon is running
  ///
  /// In en, this message translates to:
  /// **'Daemon Active'**
  String get daemonActive;

  /// Status badge shown when a CLI agent is not installed
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// Label shown while the app is detecting which CLIs are installed
  ///
  /// In en, this message translates to:
  /// **'Detecting Installed Agents'**
  String get detectingInstalled;

  /// Status message displayed during an active scan for CLI environments
  ///
  /// In en, this message translates to:
  /// **'Scanning local environments...'**
  String get scanningEnvironments;

  /// Button label to trigger a scan for installed CLI agents
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// Button label to re-run the scan for installed CLI agents
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// Button label to clear the local detection cache
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// Section heading for the list of sessions
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// Empty-state message when there are no sessions
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// Empty-state hint prompting the user to create their first session
  ///
  /// In en, this message translates to:
  /// **'Create a new session to get started.'**
  String get createSessionToStart;

  /// Heading shown above filtered search results
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// Subtitle explaining that search results span all environments
  ///
  /// In en, this message translates to:
  /// **'Showing matches across all environments.'**
  String get showingAllEnvironments;

  /// Prompt shown when no session is currently selected
  ///
  /// In en, this message translates to:
  /// **'Select a past session or create a new one.'**
  String get selectPastSession;

  /// Heading for the new-session dialog that includes the agent name
  ///
  /// In en, this message translates to:
  /// **'Initialize New {agentName} Session'**
  String initializeNewSession(String agentName);

  /// Label for a session that is currently running
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get statusRunning;

  /// Label for a session that finished successfully
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// Label for a session that finished with an error
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// Label for a session that was cancelled before completion
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// Label for a session that was launched in the local Terminal
  ///
  /// In en, this message translates to:
  /// **'Launched'**
  String get statusLaunched;

  /// Label for a session that was created but not yet launched
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get statusCreated;

  /// Timestamp label for events that occurred within the last minute
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// Relative timestamp for N minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// Relative timestamp for N hours ago
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// Relative timestamp for N days ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(int count);

  /// Dialog title for creating a new session
  ///
  /// In en, this message translates to:
  /// **'Initialize New Session'**
  String get newSessionTitle;

  /// Label for the workspace path input field
  ///
  /// In en, this message translates to:
  /// **'Workspace Path'**
  String get workspacePath;

  /// Placeholder hint for the workspace path input field
  ///
  /// In en, this message translates to:
  /// **'~/projects/my-project'**
  String get workspaceHint;

  /// Label for the session name input field
  ///
  /// In en, this message translates to:
  /// **'Session Name'**
  String get sessionName;

  /// Placeholder hint for the session name input field
  ///
  /// In en, this message translates to:
  /// **'Refactor API router...'**
  String get sessionNameHint;

  /// Label for the task prompt input field
  ///
  /// In en, this message translates to:
  /// **'Task Prompt'**
  String get promptInput;

  /// Placeholder hint for the task prompt input field
  ///
  /// In en, this message translates to:
  /// **'Describe what you want the agent to do...'**
  String get promptHint;

  /// Button label to dismiss the dialog without creating a session
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button label to create the new session and immediately start the agent
  ///
  /// In en, this message translates to:
  /// **'Create & Run'**
  String get createAndRun;

  /// Error message shown when session creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create session: {error}'**
  String createFailed(String error);

  /// Label prefix for the workspace path shown on a session card
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// Tooltip and dialog title for deleting a session
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get deleteSession;

  /// Confirmation message shown before deleting a session
  ///
  /// In en, this message translates to:
  /// **'Delete session \"{name}\"? This cannot be undone.'**
  String deleteSessionConfirm(String name);

  /// Button label confirming a delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Banner shown when the terminal process exits
  ///
  /// In en, this message translates to:
  /// **'Process exited (code {code}). The conversation was saved and can be resumed.'**
  String processExited(int code);

  /// Button to relaunch the CLI resuming the saved conversation
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get relaunchSession;

  /// Sidebar section header for the task panel
  ///
  /// In en, this message translates to:
  /// **'TASKS'**
  String get tasksSection;

  /// Button creating a new task session
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// Badge showing how many task terminals are running
  ///
  /// In en, this message translates to:
  /// **'{count} running'**
  String runningCount(int count);

  /// Empty state of the terminal pane when no task is open
  ///
  /// In en, this message translates to:
  /// **'Select a task on the left to open its terminal'**
  String get noOpenTerminal;

  /// Tooltip on the terminal tab close button
  ///
  /// In en, this message translates to:
  /// **'Close terminal'**
  String get closeTerminal;

  /// Placeholder of the inline task search field in the task panel
  ///
  /// In en, this message translates to:
  /// **'Search tasks...'**
  String get searchTasks;

  /// Agent filter chip that clears the selection (show all agents)
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allAgents;

  /// Placeholder text in the search input field
  ///
  /// In en, this message translates to:
  /// **'Search sessions, tags, or workspaces...'**
  String get searchHint;

  /// Placeholder message shown when search is not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Session search coming soon'**
  String get sessionSearchComing;

  /// Hint shown when a search returns no results
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or check local CLI paths.'**
  String get tryDifferentSearch;

  /// Title of the add-custom-agent dialog and tooltip of the + button
  ///
  /// In en, this message translates to:
  /// **'Add Custom Agent'**
  String get addCustomAgent;

  /// Label of the display-name field in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// Hint of the display-name field in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'e.g. My Agent CLI'**
  String get displayNameHint;

  /// Label of the binary field in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'Binary (command name or full path)'**
  String get binaryLabel;

  /// Hint of the binary field in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'e.g. myagent or /usr/local/bin/myagent'**
  String get binaryHint;

  /// Tooltip of the file-picker button
  ///
  /// In en, this message translates to:
  /// **'Browse…'**
  String get browse;

  /// Label of the version-flag field in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'Version Flag'**
  String get versionFlagLabel;

  /// Confirm button of the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'Add Agent'**
  String get addAgentButton;

  /// Validation error in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'Name and binary are required'**
  String get nameAndBinaryRequired;

  /// Duplicate-binary error in the add-agent dialog
  ///
  /// In en, this message translates to:
  /// **'An agent with this binary already exists'**
  String get agentAlreadyExists;

  /// Context-menu item to delete a user-added agent
  ///
  /// In en, this message translates to:
  /// **'Remove custom agent'**
  String get removeCustomAgent;

  /// Context-menu item to hide a built-in agent from the sidebar
  ///
  /// In en, this message translates to:
  /// **'Hide from list'**
  String get hideAgent;

  /// Footer label showing how many agents are hidden
  ///
  /// In en, this message translates to:
  /// **'{count} hidden'**
  String hiddenAgentsCount(int count);

  /// Action to restore all hidden agents to the sidebar
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAllAgents;

  /// Title of the install-hint dialog
  ///
  /// In en, this message translates to:
  /// **'Install {name}'**
  String installAgentTitle(String name);

  /// Body of the install-hint dialog
  ///
  /// In en, this message translates to:
  /// **'{name} was not found on your system.'**
  String agentNotFound(String name);

  /// Label above the install command in the install-hint dialog
  ///
  /// In en, this message translates to:
  /// **'Install with:'**
  String get installWith;

  /// Footer hint of the install-hint dialog
  ///
  /// In en, this message translates to:
  /// **'After installing, click the ↻ button to rescan.'**
  String get afterInstallRescan;

  /// Generic close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Tooltip for the broadcast button in the task panel header
  ///
  /// In en, this message translates to:
  /// **'Broadcast to all running agents'**
  String get broadcastTooltip;

  /// Tooltip of the broadcast button when the bar is open
  ///
  /// In en, this message translates to:
  /// **'Close broadcast'**
  String get closeBroadcast;

  /// Placeholder of the broadcast input field
  ///
  /// In en, this message translates to:
  /// **'Send to all running agents…'**
  String get broadcastHint;

  /// Badge showing how many agents will receive the broadcast
  ///
  /// In en, this message translates to:
  /// **'→ {count} agents'**
  String broadcastTargets(int count);

  /// Tooltip of the attach-files toolbar button
  ///
  /// In en, this message translates to:
  /// **'Attach files (or drag & drop / Cmd+V an image)'**
  String get attachFilesTooltip;

  /// Tooltip of the split-view toolbar button
  ///
  /// In en, this message translates to:
  /// **'Split view'**
  String get splitView;

  /// Tooltip of the split-view button when split is active
  ///
  /// In en, this message translates to:
  /// **'Exit split view'**
  String get exitSplitView;

  /// Context-menu item: open a new task in the same working directory
  ///
  /// In en, this message translates to:
  /// **'New task here'**
  String get newTaskHere;

  /// Tooltip of the ↪ hover button on a task item
  ///
  /// In en, this message translates to:
  /// **'New task in same folder'**
  String get newTaskSameFolder;

  /// Context-menu section header for dispatching to another agent
  ///
  /// In en, this message translates to:
  /// **'Send to agent'**
  String get sendToAgent;

  /// Context-menu item to reveal the working directory
  ///
  /// In en, this message translates to:
  /// **'Open in Finder'**
  String get openInFinder;

  /// Context-menu item to copy the task prompt
  ///
  /// In en, this message translates to:
  /// **'Copy prompt'**
  String get copyPrompt;

  /// Context-menu item to copy the captured session output
  ///
  /// In en, this message translates to:
  /// **'Copy output'**
  String get copyOutput;

  /// Tooltip of the output snippet in the task detail panel
  ///
  /// In en, this message translates to:
  /// **'Tap to copy full output'**
  String get tapToCopyOutput;

  /// Error shown when a required CLI agent is not installed
  ///
  /// In en, this message translates to:
  /// **'CLI {name} is not installed or not found on this system. Run Scan to detect available CLIs.'**
  String cliNotInstalled(String name);

  /// Field label when multi-dispatching to several agents
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsLabel;

  /// Header subtitle in multi-dispatch mode
  ///
  /// In en, this message translates to:
  /// **'Dispatching to {count} agents simultaneously'**
  String dispatchingToAgents(int count);

  /// Primary button in multi-dispatch mode
  ///
  /// In en, this message translates to:
  /// **'Dispatch to {count} Agents'**
  String dispatchToAgents(int count);

  /// Tooltip on the clear button of the session name field
  ///
  /// In en, this message translates to:
  /// **'Reset to auto-name'**
  String get resetToAutoName;

  /// Collapsible panel title for Claude CLI options
  ///
  /// In en, this message translates to:
  /// **'Claude Options'**
  String get claudeOptions;

  /// Label of the model picker
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// Label of the thinking-effort picker
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get thinkingLabel;

  /// Label of the permission-mode picker
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionsLabel;

  /// Switch title for --dangerously-skip-permissions
  ///
  /// In en, this message translates to:
  /// **'Skip All Permissions'**
  String get skipAllPermissions;

  /// Switch title for --print mode
  ///
  /// In en, this message translates to:
  /// **'Non-interactive'**
  String get nonInteractive;

  /// Switch subtitle for --print mode
  ///
  /// In en, this message translates to:
  /// **'--print, output and exit'**
  String get nonInteractiveDesc;

  /// Hint of the model quick-select dropdown
  ///
  /// In en, this message translates to:
  /// **'Quick select'**
  String get quickSelect;

  /// Hint of the free-form model name field
  ///
  /// In en, this message translates to:
  /// **'Or type any model API name'**
  String get typeModelName;

  /// Model dropdown: default option
  ///
  /// In en, this message translates to:
  /// **'Default (Opus 4.8, 1M context)'**
  String get modelDefaultLabel;

  /// Model dropdown: sonnet option
  ///
  /// In en, this message translates to:
  /// **'Sonnet 4.6 — Best for everyday tasks'**
  String get modelSonnetLabel;

  /// Model dropdown: haiku option
  ///
  /// In en, this message translates to:
  /// **'Haiku 4.5 — Fastest, quick answers'**
  String get modelHaikuLabel;

  /// Model dropdown: pinned opus option
  ///
  /// In en, this message translates to:
  /// **'Opus 4.8 pinned'**
  String get modelOpusPinned;

  /// Model dropdown: pinned sonnet option
  ///
  /// In en, this message translates to:
  /// **'Sonnet 4.6 pinned'**
  String get modelSonnetPinned;

  /// Thinking effort: low
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get effortLow;

  /// Thinking effort: medium
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get effortMedium;

  /// Thinking effort: high
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get effortHigh;

  /// Thinking effort: extra high
  ///
  /// In en, this message translates to:
  /// **'Extra High'**
  String get effortXhigh;

  /// Thinking effort: maximum
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get effortMax;

  /// Permission mode: default
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get permDefault;

  /// Permission mode: acceptEdits
  ///
  /// In en, this message translates to:
  /// **'Accept Edits'**
  String get permAcceptEdits;

  /// Permission mode: auto
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get permAuto;

  /// Permission mode: bypassPermissions
  ///
  /// In en, this message translates to:
  /// **'Bypass All'**
  String get permBypass;

  /// Permission mode: dontAsk
  ///
  /// In en, this message translates to:
  /// **'Don\'t Ask'**
  String get permDontAsk;

  /// Permission mode: plan
  ///
  /// In en, this message translates to:
  /// **'Plan Only'**
  String get permPlan;

  /// Palette action subtitle for New Task
  ///
  /// In en, this message translates to:
  /// **'Create a new agent task'**
  String get newTaskSubtitle;

  /// Palette action to re-run CLI detection
  ///
  /// In en, this message translates to:
  /// **'Rescan Agents'**
  String get rescanAgents;

  /// Palette action subtitle for Rescan Agents
  ///
  /// In en, this message translates to:
  /// **'Re-detect installed CLI tools'**
  String get rescanAgentsSubtitle;

  /// Palette action to open the settings drawer
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Palette action subtitle for Open Settings
  ///
  /// In en, this message translates to:
  /// **'Font size, notifications, CLI path'**
  String get openSettingsSubtitle;

  /// Hint of the palette search input
  ///
  /// In en, this message translates to:
  /// **'Search sessions, @agent filter, or run a command…'**
  String get paletteSearchHint;

  /// Empty state of palette / terminal search
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// Settings drawer title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Settings section: terminal
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get sectionTerminal;

  /// Settings section: notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionNotifications;

  /// Terminal font size setting label
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// Notification switch title
  ///
  /// In en, this message translates to:
  /// **'Task completion alerts'**
  String get taskCompletionAlerts;

  /// Notification switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Notify when a terminal task finishes'**
  String get taskCompletionAlertsDesc;

  /// Claude CLI path setting label
  ///
  /// In en, this message translates to:
  /// **'Binary path override'**
  String get binaryPathOverride;

  /// Claude CLI path setting subtitle
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-detect (~/.local/bin/claude first)'**
  String get binaryPathDesc;

  /// Confirm body when closing a running task tab
  ///
  /// In en, this message translates to:
  /// **'This task is still running. Stop it and close?'**
  String get taskStillRunningStop;

  /// Confirm body when closing a running terminal
  ///
  /// In en, this message translates to:
  /// **'This task is still running. Close and stop it?'**
  String get taskStillRunningClose;

  /// Confirm dialog: cancel closing
  ///
  /// In en, this message translates to:
  /// **'Keep Running'**
  String get keepRunning;

  /// Confirm dialog: stop the task and close
  ///
  /// In en, this message translates to:
  /// **'Stop & Close'**
  String get stopAndClose;

  /// Empty terminal pane keyboard hint
  ///
  /// In en, this message translates to:
  /// **'Cmd+N to create a new task'**
  String get cmdNHint;

  /// Snackbar after exporting terminal output
  ///
  /// In en, this message translates to:
  /// **'Saved to ~/Desktop/{name}'**
  String savedToDesktop(String name);

  /// Snackbar when terminal export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// Button on an exited terminal to relaunch with a follow-up prompt
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get followUp;

  /// Tooltip of the clear-finished button in the task panel
  ///
  /// In en, this message translates to:
  /// **'Clear completed / failed sessions'**
  String get clearFinishedSessions;

  /// Tooltip of the Insert attachments button
  ///
  /// In en, this message translates to:
  /// **'Type all paths into the input now'**
  String get insertPathsTooltip;

  /// Tooltip of the Insert button when the PTY has exited
  ///
  /// In en, this message translates to:
  /// **'Terminal not running'**
  String get terminalNotRunning;

  /// Insert attachments button label
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insert;

  /// Tooltip of the clear attachments button
  ///
  /// In en, this message translates to:
  /// **'Clear all attachments'**
  String get clearAllAttachments;

  /// Shown when an image attachment preview cannot load
  ///
  /// In en, this message translates to:
  /// **'Preview failed: {error}'**
  String previewFailed(String error);

  /// Hint of the in-terminal search field
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchInTerminal;

  /// Context menu: pin a session to the top of the list
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinSession;

  /// Context menu: unpin a session
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinSession;

  /// Context menu: relay this session output to ALL other detected agents simultaneously
  ///
  /// In en, this message translates to:
  /// **'Relay to all agents'**
  String get relayToAll;

  /// Subtitle under relay-to-all: shows how many agents will receive the task
  ///
  /// In en, this message translates to:
  /// **'{count} other agents'**
  String relayToAllSubtitle(int count);

  /// Sidebar agent badge: agent binary was detected
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get agentFound;

  /// Title of the keyboard shortcuts help dialog
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// Shortcuts dialog section: global shortcuts
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get shortcutsGlobal;

  /// Shortcuts dialog section: tab navigation
  ///
  /// In en, this message translates to:
  /// **'Terminal Tabs'**
  String get shortcutsTabs;

  /// Shortcuts dialog section: in-terminal shortcuts
  ///
  /// In en, this message translates to:
  /// **'In Terminal'**
  String get shortcutsTerminal;

  /// Shortcut description: open command palette
  ///
  /// In en, this message translates to:
  /// **'Command Palette'**
  String get shortcutCommandPalette;

  /// Shortcut description: new task from clipboard
  ///
  /// In en, this message translates to:
  /// **'New Task from Clipboard'**
  String get shortcutNewTaskClipboard;

  /// Shortcut description: focus next terminal tab
  ///
  /// In en, this message translates to:
  /// **'Next Tab'**
  String get shortcutNextTab;

  /// Shortcut description: focus previous terminal tab
  ///
  /// In en, this message translates to:
  /// **'Previous Tab'**
  String get shortcutPrevTab;

  /// Shortcut description: jump directly to terminal tab by position
  ///
  /// In en, this message translates to:
  /// **'Jump to Tab 1–9'**
  String get shortcutJumpToTab;

  /// Shortcut description: close current terminal tab
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get shortcutCloseTab;

  /// Shortcut description: open terminal search bar
  ///
  /// In en, this message translates to:
  /// **'Search in Terminal'**
  String get shortcutSearch;

  /// Shortcut description: export terminal output to Desktop
  ///
  /// In en, this message translates to:
  /// **'Export Terminal'**
  String get shortcutExport;

  /// Shortcut description: show this shortcuts panel
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcutShowShortcuts;

  /// Context menu item to add/edit a user note on a session
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get editNote;

  /// Placeholder text in the note editing dialog
  ///
  /// In en, this message translates to:
  /// **'Add a note to this session...'**
  String get notePlaceholder;

  /// Snackbar confirmation after saving a note (unused if silent)
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// Generic save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Context menu: export session metadata + output as a Markdown file to Desktop
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get exportAsMarkdown;

  /// Markdown export label: agent name
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentLabel;

  /// Markdown export label: session status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// Markdown export / detail panel label for the working directory
  ///
  /// In en, this message translates to:
  /// **'Working Directory'**
  String get workingDirectory;

  /// Markdown export label: session duration
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Markdown export section header: the input prompt/task
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get inputPrompt;

  /// Markdown export section header: user notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Tooltip for the task panel sort button
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// Sort option: newest sessions at top
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// Sort option: oldest sessions at top
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// Sort option: alphabetical by session name
  ///
  /// In en, this message translates to:
  /// **'A → Z'**
  String get sortByName;

  /// Sort option: longest-duration sessions at top
  ///
  /// In en, this message translates to:
  /// **'Longest first'**
  String get sortByDuration;

  /// Title of the session statistics dialog
  ///
  /// In en, this message translates to:
  /// **'Session Statistics'**
  String get statsTitle;

  /// Stats table column: agent name
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get statsAgent;

  /// Stats table column: total session count
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statsTotal;

  /// Stats table column: completed session count
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statsDone;

  /// Stats table column: failed/cancelled session count
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statsFailed;

  /// Stats table column: average session duration
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get statsAvgTime;

  /// Stats footer: total compute time across all sessions
  ///
  /// In en, this message translates to:
  /// **'Total compute'**
  String get statsTotalTime;

  /// Shown when there are no sessions to compute stats from
  ///
  /// In en, this message translates to:
  /// **'No sessions recorded yet.'**
  String get noStatsYet;

  /// Tooltip on the output snippet in the session detail panel
  ///
  /// In en, this message translates to:
  /// **'Tap to view full output'**
  String get tapToViewOutput;

  /// Title of the full output viewer dialog
  ///
  /// In en, this message translates to:
  /// **'Full Output'**
  String get viewFullOutput;

  /// Exit code label in the session detail panel
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String exitCode(int code);

  /// Tooltip/label for the retry-all-failed button in the task panel footer
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get retryAllFailed;

  /// Hover button tooltip on failed/cancelled session rows
  ///
  /// In en, this message translates to:
  /// **'Retry this session'**
  String get retrySession;

  /// Context menu: clone a session with the same prompt and working directory
  ///
  /// In en, this message translates to:
  /// **'Clone Session'**
  String get cloneSession;

  /// Tooltip on the bookmark-add button next to the workspace field
  ///
  /// In en, this message translates to:
  /// **'Save as bookmark'**
  String get addBookmark;

  /// Placeholder in the bookmark-name dialog
  ///
  /// In en, this message translates to:
  /// **'e.g. My Flutter App'**
  String get bookmarkNameHint;

  /// Snackbar shown after saving a workspace bookmark
  ///
  /// In en, this message translates to:
  /// **'Bookmark saved'**
  String get bookmarkSaved;

  /// Context menu item and dialog title for setting a session color label
  ///
  /// In en, this message translates to:
  /// **'Set color label'**
  String get setColor;

  /// Button in color picker to remove the color label
  ///
  /// In en, this message translates to:
  /// **'Clear color'**
  String get clearColor;

  /// Tooltip for the group-by-directory toggle button in the task panel header
  ///
  /// In en, this message translates to:
  /// **'Group by project'**
  String get groupByProject;

  /// Group header label for sessions with no working directory set
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get groupOther;

  /// Tooltip of the prompt templates button in the terminal toolbar
  ///
  /// In en, this message translates to:
  /// **'Prompt templates'**
  String get promptTemplatesTooltip;

  /// Tooltip for the shared-memory button on a project group header
  ///
  /// In en, this message translates to:
  /// **'Shared project memory'**
  String get sharedMemoryTooltip;

  /// Title of the shared project memory editor dialog
  ///
  /// In en, this message translates to:
  /// **'Shared project memory'**
  String get sharedMemoryTitle;

  /// Explanatory subtitle in the shared project memory editor dialog
  ///
  /// In en, this message translates to:
  /// **'Shared with every agent in this project — synced into CLAUDE.md, AGENTS.md and GEMINI.md when a session launches.'**
  String get sharedMemoryDescription;

  /// Placeholder text in the shared project memory editor field
  ///
  /// In en, this message translates to:
  /// **'Conventions, context and notes to share with every agent in this project…'**
  String get sharedMemoryPlaceholder;

  /// Title of the broadcast dialog showing how many agents will receive the message
  ///
  /// In en, this message translates to:
  /// **'Broadcast to {count} running agents'**
  String broadcastTitle(int count);

  /// Explanatory subtitle in the broadcast dialog
  ///
  /// In en, this message translates to:
  /// **'Sends your message directly to every running agent\'s stdin — all agents receive it simultaneously.'**
  String get broadcastDescription;

  /// Placeholder text in the broadcast message input field
  ///
  /// In en, this message translates to:
  /// **'Type a message or prompt to broadcast to all running agents…'**
  String get broadcastPlaceholder;

  /// Label for the send button in the broadcast dialog
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get broadcastSend;

  /// Tooltip for the per-session inject-message hover button on running task rows
  ///
  /// In en, this message translates to:
  /// **'Send to this agent'**
  String get injectMessageTooltip;

  /// Title of the inject-message dialog for a specific session
  ///
  /// In en, this message translates to:
  /// **'Send to {agentName}'**
  String injectMessageTitle(String agentName);

  /// Explanatory subtitle in the inject-message dialog for a single agent
  ///
  /// In en, this message translates to:
  /// **'Sends directly to this agent\'s stdin.'**
  String get injectMessageDescription;

  /// Keyboard shortcuts dialog section title for agent cluster shortcuts
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get shortcutsAgents;

  /// Description of the Cmd+Shift+B keyboard shortcut
  ///
  /// In en, this message translates to:
  /// **'Broadcast to all running agents'**
  String get shortcutBroadcast;

  /// Description of the Cmd+Shift+I keyboard shortcut
  ///
  /// In en, this message translates to:
  /// **'Send message to active agent'**
  String get shortcutInjectActive;

  /// Command palette action title for running a task on all detected CLI agents
  ///
  /// In en, this message translates to:
  /// **'Run on all agents'**
  String get runOnAllAgents;

  /// Command palette action subtitle showing how many agents will receive the task
  ///
  /// In en, this message translates to:
  /// **'Create a session for each of the {count} detected agents'**
  String runOnAllAgentsSubtitle(int count);

  /// Command palette action subtitle for the broadcast action
  ///
  /// In en, this message translates to:
  /// **'⇧⌘B · Send a prompt to all {count} running agents'**
  String commandBroadcastSubtitle(int count);

  /// Rescan button tooltip while detection is in progress
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// Rescan button tooltip when detection finished under a minute ago
  ///
  /// In en, this message translates to:
  /// **'Last scanned: just now'**
  String get lastScannedJustNow;

  /// Rescan button tooltip when detection finished N minutes ago
  ///
  /// In en, this message translates to:
  /// **'Last scanned: {minutes}m ago'**
  String lastScannedMinutesAgo(int minutes);

  /// Rescan button tooltip when detection finished N hours ago
  ///
  /// In en, this message translates to:
  /// **'Last scanned: {hours}h ago'**
  String lastScannedHoursAgo(int hours);

  /// Rescan button tooltip when detection finished N days ago
  ///
  /// In en, this message translates to:
  /// **'Last scanned: {days}d ago'**
  String lastScannedDaysAgo(int days);

  /// Title of the cluster comparison dialog showing all sessions created in a multi-agent run
  ///
  /// In en, this message translates to:
  /// **'Cluster Run · {count} agents'**
  String clusterRunTitle(int count);

  /// Title of the workflow templates management dialog
  ///
  /// In en, this message translates to:
  /// **'Workflow Templates'**
  String get workflowTemplates;

  /// Button label to create a new workflow template
  ///
  /// In en, this message translates to:
  /// **'New Workflow'**
  String get workflowNew;

  /// Tooltip for the edit button on a workflow template card
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get workflowEdit;

  /// Tooltip for the delete button on a workflow template card
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get workflowDelete;

  /// Tooltip for the launch button on a workflow template card
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get workflowLaunch;

  /// Button label to import a workflow template from JSON
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get workflowImport;

  /// Tooltip for the export button on a workflow template card
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get workflowExport;

  /// Empty state message when no workflow templates exist
  ///
  /// In en, this message translates to:
  /// **'No workflow templates yet.'**
  String get workflowNoTemplates;

  /// Hint text below the empty state message
  ///
  /// In en, this message translates to:
  /// **'Create one to define multi-agent DAG workflows.'**
  String get workflowCreateHint;

  /// Confirmation message when deleting a workflow template
  ///
  /// In en, this message translates to:
  /// **'Cannot be undone.'**
  String get workflowDeleteConfirm;

  /// Title of the delete confirmation dialog for a workflow template
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String workflowDeleteTitle(String name);

  /// Stats line on a workflow template card
  ///
  /// In en, this message translates to:
  /// **'{agents} agents, {nodes} nodes, {edges} edges'**
  String workflowStats(int agents, int nodes, int edges);

  /// Title of the workflow editor dialog
  ///
  /// In en, this message translates to:
  /// **'Workflow Editor'**
  String get workflowEditorTitle;

  /// Label for the workflow name field
  ///
  /// In en, this message translates to:
  /// **'Workflow Name'**
  String get workflowName;

  /// Label for the workflow description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get workflowDescription;

  /// Label for the default working directory field
  ///
  /// In en, this message translates to:
  /// **'Working Directory'**
  String get workflowWorkingDir;

  /// Section header for the nodes list in the workflow editor
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get workflowNodes;

  /// Section header for the edges list in the workflow editor
  ///
  /// In en, this message translates to:
  /// **'Edges'**
  String get workflowEdges;

  /// Button to add a new node to the workflow
  ///
  /// In en, this message translates to:
  /// **'Add Node'**
  String get workflowAddNode;

  /// Button to add a new edge to the workflow
  ///
  /// In en, this message translates to:
  /// **'Add Edge'**
  String get workflowAddEdge;

  /// Label for the node name field
  ///
  /// In en, this message translates to:
  /// **'Node Name'**
  String get workflowNodeName;

  /// Label for the agent selector dropdown in a node
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get workflowNodeAgent;

  /// Label for the prompt template field in a node
  ///
  /// In en, this message translates to:
  /// **'Prompt Template'**
  String get workflowNodePrompt;

  /// Label for the source node dropdown in an edge
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get workflowEdgeFrom;

  /// Label for the target node dropdown in an edge
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get workflowEdgeTo;

  /// Label for the edge condition dropdown
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get workflowEdgeCondition;

  /// Title of the workflow run monitor dialog
  ///
  /// In en, this message translates to:
  /// **'Workflow Run'**
  String get workflowRunTitle;

  /// Button to cancel a running workflow
  ///
  /// In en, this message translates to:
  /// **'Cancel Workflow'**
  String get workflowRunCancel;

  /// Button to retry a failed workflow node
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workflowRunRetry;

  /// Progress indicator in the workflow run monitor
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} nodes completed'**
  String workflowRunProgress(int completed, int total);

  /// Description of the Cmd+Shift+W keyboard shortcut in the shortcuts dialog
  ///
  /// In en, this message translates to:
  /// **'Open Workflow Templates'**
  String get shortcutWorkflow;

  /// Toggle title for overriding the auto-generated CLI launch flags
  ///
  /// In en, this message translates to:
  /// **'Custom launch arguments'**
  String get customArgsLabel;

  /// Subtitle under the custom launch arguments toggle
  ///
  /// In en, this message translates to:
  /// **'Override the auto-generated flags'**
  String get customArgsDesc;

  /// Placeholder for the custom launch arguments text field
  ///
  /// In en, this message translates to:
  /// **'e.g. --model sonnet --permission-mode plan'**
  String get customArgsHint;

  /// Helper text explaining that an empty custom-args field launches with no flags
  ///
  /// In en, this message translates to:
  /// **'Leave empty to launch the bare command with no flags.'**
  String get customArgsEmptyHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
