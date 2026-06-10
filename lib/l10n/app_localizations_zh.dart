// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Agent CLI 管理器';

  @override
  String get agentOSCli => 'AgentDock';

  @override
  String get localEnvironments => '本地环境';

  @override
  String get daemonActive => '守护进程运行中';

  @override
  String get missing => '未安装';

  @override
  String get detectingInstalled => '正在检测已安装的 Agent';

  @override
  String get scanningEnvironments => '正在扫描本地环境...';

  @override
  String get scan => '扫描';

  @override
  String get rescan => '重新扫描';

  @override
  String get clearCache => '清除缓存';

  @override
  String get sessions => '会话';

  @override
  String get noSessionsYet => '暂无会话';

  @override
  String get createSessionToStart => '创建一个新会话开始使用。';

  @override
  String get searchResults => '搜索结果';

  @override
  String get showingAllEnvironments => '显示所有环境中的匹配结果。';

  @override
  String get selectPastSession => '选择一个历史会话或创建新会话。';

  @override
  String initializeNewSession(String agentName) {
    return '初始化 $agentName 新会话';
  }

  @override
  String get statusRunning => '运行中';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusCancelled => '已取消';

  @override
  String get statusLaunched => '已启动';

  @override
  String get statusCreated => '已创建';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String get newSessionTitle => '初始化新会话';

  @override
  String get workspacePath => '工作区路径';

  @override
  String get workspaceHint => '~/projects/my-project';

  @override
  String get sessionName => '会话名称';

  @override
  String get sessionNameHint => '重构 API 路由...';

  @override
  String get promptInput => '任务提示';

  @override
  String get promptHint => '描述你希望 agent 执行的任务...';

  @override
  String get cancel => '取消';

  @override
  String get createAndRun => '创建并运行';

  @override
  String createFailed(String error) {
    return '创建会话失败：$error';
  }

  @override
  String get workspace => '工作区';

  @override
  String get deleteSession => '删除会话';

  @override
  String deleteSessionConfirm(String name) {
    return '确定删除会话 \"$name\" 吗？此操作无法撤销。';
  }

  @override
  String get delete => '删除';

  @override
  String processExited(int code) {
    return '进程已退出（代码 $code）。会话已保存，可以恢复。';
  }

  @override
  String get relaunchSession => '恢复会话';

  @override
  String get tasksSection => '任务列表';

  @override
  String get newTask => '新建任务';

  @override
  String runningCount(int count) {
    return '$count 个运行中';
  }

  @override
  String get noOpenTerminal => '在左侧点击任务以打开终端';

  @override
  String get closeTerminal => '关闭终端';

  @override
  String get searchTasks => '搜索任务...';

  @override
  String get allAgents => '全部';

  @override
  String get searchHint => '搜索会话、标签或工作区...';

  @override
  String get sessionSearchComing => '会话搜索即将推出';

  @override
  String get tryDifferentSearch => '尝试其他搜索词或检查本地 CLI 路径。';

  @override
  String get addCustomAgent => '添加自定义 Agent';

  @override
  String get displayNameLabel => '显示名称';

  @override
  String get displayNameHint => '例如：My Agent CLI';

  @override
  String get binaryLabel => '可执行文件（命令名或完整路径）';

  @override
  String get binaryHint => '例如：myagent 或 /usr/local/bin/myagent';

  @override
  String get browse => '浏览…';

  @override
  String get versionFlagLabel => '版本参数';

  @override
  String get addAgentButton => '添加 Agent';

  @override
  String get nameAndBinaryRequired => '名称和可执行文件为必填项';

  @override
  String get agentAlreadyExists => '已存在使用此可执行文件的 Agent';

  @override
  String get removeCustomAgent => '移除自定义 Agent';

  @override
  String get hideAgent => '从列表隐藏';

  @override
  String hiddenAgentsCount(int count) {
    return '已隐藏 $count 个';
  }

  @override
  String get showAllAgents => '全部显示';

  @override
  String installAgentTitle(String name) {
    return '安装 $name';
  }

  @override
  String agentNotFound(String name) {
    return '未在您的系统上找到 $name。';
  }

  @override
  String get installWith => '安装命令：';

  @override
  String get afterInstallRescan => '安装完成后，点击 ↻ 按钮重新扫描。';

  @override
  String get close => '关闭';

  @override
  String get broadcastTooltip => '广播给所有运行中的智能体';

  @override
  String get closeBroadcast => '关闭广播';

  @override
  String get broadcastHint => '发送给所有运行中的 Agent…';

  @override
  String broadcastTargets(int count) {
    return '→ $count 个 Agent';
  }

  @override
  String get attachFilesTooltip => '附加文件（或拖放 / Cmd+V 粘贴图片）';

  @override
  String get splitView => '分屏视图';

  @override
  String get exitSplitView => '退出分屏';

  @override
  String get newTaskHere => '在此新建任务';

  @override
  String get newTaskSameFolder => '在同一文件夹新建任务';

  @override
  String get sendToAgent => '发送给 Agent';

  @override
  String get openInFinder => '在 Finder 中打开';

  @override
  String get copyPrompt => '复制提示词';

  @override
  String get copyOutput => '复制输出';

  @override
  String get tapToCopyOutput => '点击复制完整输出';

  @override
  String cliNotInstalled(String name) {
    return 'CLI $name 未在本系统上安装。请运行扫描检测可用的 CLI。';
  }

  @override
  String get agentsLabel => '智能体';

  @override
  String dispatchingToAgents(int count) {
    return '同时分发给 $count 个智能体';
  }

  @override
  String dispatchToAgents(int count) {
    return '分发给 $count 个智能体';
  }

  @override
  String get resetToAutoName => '恢复自动命名';

  @override
  String get claudeOptions => 'Claude 选项';

  @override
  String get modelLabel => '模型';

  @override
  String get thinkingLabel => '思考力度';

  @override
  String get permissionsLabel => '权限模式';

  @override
  String get skipAllPermissions => '跳过所有权限确认';

  @override
  String get nonInteractive => '非交互模式';

  @override
  String get nonInteractiveDesc => '--print,输出后退出';

  @override
  String get quickSelect => '快速选择';

  @override
  String get typeModelName => '或输入任意模型 API 名称';

  @override
  String get modelDefaultLabel => '默认(Opus 4.8,1M 上下文)';

  @override
  String get modelSonnetLabel => 'Sonnet 4.6 — 日常任务首选';

  @override
  String get modelHaikuLabel => 'Haiku 4.5 — 最快,适合快速问答';

  @override
  String get modelOpusPinned => '固定 Opus 4.8';

  @override
  String get modelSonnetPinned => '固定 Sonnet 4.6';

  @override
  String get effortLow => '低';

  @override
  String get effortMedium => '中';

  @override
  String get effortHigh => '高';

  @override
  String get effortXhigh => '超高';

  @override
  String get effortMax => '最高';

  @override
  String get permDefault => '默认';

  @override
  String get permAcceptEdits => '自动接受编辑';

  @override
  String get permAuto => '自动';

  @override
  String get permBypass => '绕过全部权限';

  @override
  String get permDontAsk => '不再询问';

  @override
  String get permPlan => '仅规划';

  @override
  String get newTaskSubtitle => '创建新的智能体任务';

  @override
  String get rescanAgents => '重新扫描 Agent';

  @override
  String get rescanAgentsSubtitle => '重新检测已安装的 CLI 工具';

  @override
  String get openSettings => '打开设置';

  @override
  String get openSettingsSubtitle => '字体大小、通知、CLI 路径';

  @override
  String get paletteSearchHint => '搜索会话、@agent 过滤或运行命令…';

  @override
  String get noResults => '无结果';

  @override
  String get settings => '设置';

  @override
  String get sectionTerminal => '终端';

  @override
  String get sectionNotifications => '通知';

  @override
  String get fontSize => '字体大小';

  @override
  String get taskCompletionAlerts => '任务完成提醒';

  @override
  String get taskCompletionAlertsDesc => '终端任务结束时发送系统通知';

  @override
  String get binaryPathOverride => '二进制路径覆盖';

  @override
  String get binaryPathDesc => '留空则自动检测(优先 ~/.local/bin/claude)';

  @override
  String get taskStillRunningStop => '该任务仍在运行,停止并关闭吗?';

  @override
  String get taskStillRunningClose => '该任务仍在运行,关闭并停止吗?';

  @override
  String get keepRunning => '继续运行';

  @override
  String get stopAndClose => '停止并关闭';

  @override
  String get cmdNHint => '按 Cmd+N 新建任务';

  @override
  String savedToDesktop(String name) {
    return '已保存到 ~/Desktop/$name';
  }

  @override
  String exportFailed(String error) {
    return '导出失败:$error';
  }

  @override
  String get followUp => '追问';

  @override
  String get clearFinishedSessions => '清除已完成/失败的会话';

  @override
  String get insertPathsTooltip => '立即将所有路径输入到终端';

  @override
  String get terminalNotRunning => '终端未运行';

  @override
  String get insert => '插入';

  @override
  String get clearAllAttachments => '清除所有附件';

  @override
  String previewFailed(String error) {
    return '预览失败:$error';
  }

  @override
  String get searchInTerminal => '搜索…';

  @override
  String get pinSession => '置顶';

  @override
  String get unpinSession => '取消置顶';

  @override
  String get relayToAll => '分发给所有智能体';

  @override
  String relayToAllSubtitle(int count) {
    return '另外 $count 个智能体';
  }

  @override
  String get agentFound => '已检测';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get shortcutsGlobal => '全局';

  @override
  String get shortcutsTabs => '终端标签页';

  @override
  String get shortcutsTerminal => '终端内';

  @override
  String get shortcutCommandPalette => '命令面板';

  @override
  String get shortcutNewTaskClipboard => '从剪贴板新建任务';

  @override
  String get shortcutNextTab => '下一标签页';

  @override
  String get shortcutPrevTab => '上一标签页';

  @override
  String get shortcutJumpToTab => '跳转到第 1–9 个标签页';

  @override
  String get shortcutCloseTab => '关闭标签页';

  @override
  String get shortcutSearch => '在终端中搜索';

  @override
  String get shortcutExport => '导出终端内容';

  @override
  String get shortcutShowShortcuts => '键盘快捷键';

  @override
  String get editNote => '编辑备注';

  @override
  String get notePlaceholder => '为此会话添加备注...';

  @override
  String get noteSaved => '备注已保存';

  @override
  String get save => '保存';

  @override
  String get exportAsMarkdown => '导出为 Markdown';

  @override
  String get agentLabel => '智能体';

  @override
  String get statusLabel => '状态';

  @override
  String get workingDirectory => '工作目录';

  @override
  String get duration => '耗时';

  @override
  String get inputPrompt => '任务';

  @override
  String get notes => '备注';

  @override
  String get sortLabel => '排序';

  @override
  String get sortNewest => '最新优先';

  @override
  String get sortOldest => '最早优先';

  @override
  String get sortByName => 'A → Z';

  @override
  String get sortByDuration => '耗时最长优先';

  @override
  String get statsTitle => '会话统计';

  @override
  String get statsAgent => '智能体';

  @override
  String get statsTotal => '总数';

  @override
  String get statsDone => '已完成';

  @override
  String get statsFailed => '失败';

  @override
  String get statsAvgTime => '均耗时';

  @override
  String get statsTotalTime => '总计算时间';

  @override
  String get noStatsYet => '暂无会话记录。';

  @override
  String get tapToViewOutput => '点击查看完整输出';

  @override
  String get viewFullOutput => '完整输出';

  @override
  String exitCode(int code) {
    return '退出码 $code';
  }

  @override
  String get retryAllFailed => '重试失败';

  @override
  String get retrySession => '重试此会话';

  @override
  String get cloneSession => '克隆会话';

  @override
  String get addBookmark => '保存为书签';

  @override
  String get bookmarkNameHint => '例：我的 Flutter 项目';

  @override
  String get bookmarkSaved => '书签已保存';

  @override
  String get setColor => '设置颜色标签';

  @override
  String get clearColor => '清除颜色';

  @override
  String get groupByProject => '按项目分组';

  @override
  String get groupOther => '其他';

  @override
  String get promptTemplatesTooltip => '提示词模板';

  @override
  String get sharedMemoryTooltip => '项目共享记忆';

  @override
  String get sharedMemoryTitle => '项目共享记忆';

  @override
  String get sharedMemoryDescription =>
      '与本项目下所有智能体共享 —— 会话启动时自动同步进 CLAUDE.md、AGENTS.md 和 GEMINI.md。';

  @override
  String get sharedMemoryPlaceholder => '在此填写要与本项目所有智能体共享的约定、上下文与备注……';

  @override
  String broadcastTitle(int count) {
    return '广播给 $count 个运行中的智能体';
  }

  @override
  String get broadcastDescription => '直接发送到每个运行中智能体的标准输入 —— 所有智能体同时接收。';

  @override
  String get broadcastPlaceholder => '输入要广播给所有运行中智能体的消息或提示词……';

  @override
  String get broadcastSend => '发送';

  @override
  String get injectMessageTooltip => '发送给此智能体';

  @override
  String injectMessageTitle(String agentName) {
    return '发送给 $agentName';
  }

  @override
  String get injectMessageDescription => '直接发送到此智能体的标准输入。';

  @override
  String get shortcutsAgents => '智能体集群';

  @override
  String get shortcutBroadcast => '广播给所有运行中的智能体';

  @override
  String get shortcutInjectActive => '向当前活动智能体发送消息';

  @override
  String get runOnAllAgents => '在所有智能体上运行';

  @override
  String runOnAllAgentsSubtitle(int count) {
    return '为 $count 个已检测到的智能体各创建一个会话';
  }

  @override
  String commandBroadcastSubtitle(int count) {
    return '⇧⌘B · 向所有 $count 个运行中的智能体发送提示词';
  }

  @override
  String get scanning => '正在扫描…';

  @override
  String get lastScannedJustNow => '上次扫描：刚刚';

  @override
  String lastScannedMinutesAgo(int minutes) {
    return '上次扫描：$minutes 分钟前';
  }

  @override
  String lastScannedHoursAgo(int hours) {
    return '上次扫描：$hours 小时前';
  }

  @override
  String lastScannedDaysAgo(int days) {
    return '上次扫描：$days 天前';
  }

  @override
  String clusterRunTitle(int count) {
    return '集群运行 · $count 个智能体';
  }

  @override
  String get workflowTemplates => '工作流模板';

  @override
  String get workflowNew => '新建工作流';

  @override
  String get workflowEdit => '编辑';

  @override
  String get workflowDelete => '删除';

  @override
  String get workflowLaunch => '启动';

  @override
  String get workflowImport => '导入';

  @override
  String get workflowExport => '导出';

  @override
  String get workflowNoTemplates => '暂无工作流模板。';

  @override
  String get workflowCreateHint => '创建一个来定义多智能体 DAG 工作流。';

  @override
  String get workflowDeleteConfirm => '此操作无法撤销。';

  @override
  String workflowDeleteTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String workflowStats(int agents, int nodes, int edges) {
    return '$agents 个智能体，$nodes 个节点，$edges 条边';
  }

  @override
  String get workflowEditorTitle => '工作流编辑器';

  @override
  String get workflowName => '工作流名称';

  @override
  String get workflowDescription => '描述';

  @override
  String get workflowWorkingDir => '工作目录';

  @override
  String get workflowNodes => '节点';

  @override
  String get workflowEdges => '边';

  @override
  String get workflowAddNode => '添加节点';

  @override
  String get workflowAddEdge => '添加边';

  @override
  String get workflowNodeName => '节点名称';

  @override
  String get workflowNodeAgent => '智能体';

  @override
  String get workflowNodePrompt => '提示词模板';

  @override
  String get workflowEdgeFrom => '起始节点';

  @override
  String get workflowEdgeTo => '目标节点';

  @override
  String get workflowEdgeCondition => '条件';

  @override
  String get workflowRunTitle => '工作流运行';

  @override
  String get workflowRunCancel => '取消工作流';

  @override
  String get workflowRunRetry => '重试';

  @override
  String workflowRunProgress(int completed, int total) {
    return '已完成 $completed/$total 个节点';
  }

  @override
  String get shortcutWorkflow => '打开工作流模板';

  @override
  String get customArgsLabel => '自定义启动参数';

  @override
  String get customArgsDesc => '覆盖自动生成的参数';

  @override
  String get customArgsHint => '例如 --model sonnet --permission-mode plan';

  @override
  String get customArgsEmptyHint => '留空则不带任何参数启动该命令。';
}
