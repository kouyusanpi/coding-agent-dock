# Autopilot 功能优化方案

> 版本: v1.0 | 日期: 2026-06-10 | 状态: 待评审

---

## 1. 现状摘要

基于 2026-06-10 完成的 Autopilot 全链路量化分析，核心问题如下：

| 维度 | 现状 | 问题 |
|---|---|---|
| 代码规模 | 3020 行源码 / 921 行测试 | 测试/源码比仅 30.5% |
| 面板组件 | `autopilot_panel.dart` 1678 行单体 widget | 占源码 55%，仅 2 个 widget test |
| 静默检测 | `Timer.periodic(2s)` 无条件轮询 | 有效触发率仅 ~10%，90% tick 为无效计算 |
| UI 刷新 | 1s ticker + manager listener 触发完整 `setState` | 每次刷新重绘 1678 行 widget 树 |
| LLM 层 | 243 行源码 | **零测试覆盖** |
| Token 消耗 | 每次 evaluate 发送 120 行未过滤终端输出 | 1000-2000 tokens/次，20 次迭代 ≈ 40000 tokens |
| 错误处理 | LLM 失败后静默等 30s 重试 | 无连续失败计数，无快速失败 |
| 历史持久化 | 仅存元数据（goal, status, steps） | LLM transcript 和 timeline log 引擎 dispose 后丢失 |

---

## 2. 极致体验量化目标

### 2.1 性能目标

| 指标 | 当前值 | 目标值 | 测量方法 |
|---|---|---|---|
| 静默检测 CPU 浪费率 | ~90% 无效 tick | ≤5% | `InstrumentedTimer` 统计有效/无效回调比 |
| Panel 帧渲染时间 (90th) | 未测量 | <16ms（60fps） | Flutter DevTools Performance overlay |
| Panel 帧渲染时间 (99th) | 未测量 | <32ms | Flutter DevTools |
| 静默检测→evaluate 触发延迟 | 2s (pollInterval) | <500ms | 事件驱动后首次触发时间 |
| LLM token 消耗 (evaluate avg) | ~1500 tokens/次 | ≤800 tokens/次（降低 47%） | LLM API response `usage.prompt_tokens` |
| 历史记录读取延迟 | 0.5-2ms/次 | <0.1ms/次（恒定 O(1)） | `Stopwatch` 测量 getter 调用 |
| `notifyListeners` 高频场景 | 60-80 次/run | ≤20 次/run（降低 70%） | 引擎内部计数器 |

### 2.2 工程质量目标

| 指标 | 当前值 | 目标值 |
|---|---|---|
| 测试/源码比 | 30.5% | ≥70% |
| Panel widget test 数量 | 2 | ≥15 |
| LLM 层测试覆盖 | 0% | ≥80% |
| 单文件最大行数 | 1678 (panel) | ≤500（拆分后） |
| 圈复杂度 (cyclomatic) | `_evaluate` 方法 ~15 | ≤10 per method |

### 2.3 用户体验目标

| 场景 | 当前体验 | 目标体验 |
|---|---|---|
| Agent 工作中 | 仅显示倒计时，无 agent 产出 | 实时终端摘要在 panel 内可见，最近 5 行滚动显示 |
| LLM 决策追溯 | 全部折叠，逐条展开 | 一键展开全部 / 一次 LLM 调用的 diff 视图 |
| LLM 连续失败 | 静默重试直到用户手动停止 | 连续 3 次失败后自动停止 + 明确错误原因卡片 |
| Run 完成后的选中 | 自动切到第一个 running run | 保留当前选中，显示 "已完成" badge |
| 历史复盘 | 仅元数据 | 保存最近 5 次 interaction 摘要 + 最后 3 次完整 transcript |

---

## 3. 优化路线图

```
Phase 1 (Week 1-2)          Phase 2 (Week 3-4)          Phase 3 (Week 5-6)
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ 基础设施 + 性能攻坚  │ → │ 体验增强 + 测试补全  │ → │ 智能化 + 持久化完善  │
│                     │    │                     │    │                     │
│ · 静默检测事件驱动   │    │ · Panel 局部刷新     │    │ · 输出智能过滤       │
│ · LLM 快速失败       │    │ · 终端实时预览       │    │ · Interaction 持久化  │
│ · 持久化去抖动       │    │ · 一键展开 transcript│    │ · Resumability 增强  │
│ · LLM 层单元测试     │    │ · 选中锁定           │    │ · E2E 集成测试       │
│ · Panel widget 拆分  │    │ · Panel widget 测试  │    │ · Per-run 参数       │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

---

## 4. 详细任务清单

### Phase 1 — 基础设施 + 性能攻坚（预估 8-10 人天）

#### P1-1: 静默检测改为事件驱动
- **文件**: `lib/services/autopilot_engine.dart`
- **当前**: `Timer.periodic(pollInterval)` 每 2s 轮询
- **目标**: 用 `_lastActivity` 时间戳 + 单次 `Timer(duration, callback)` 替代，收到输出时重置
- **实现要点**:
  ```dart
  void _scheduleQuietCheck() {
    _quietTimer?.cancel();
    final remaining = Duration(seconds: quietSeconds) -
        DateTime.now().difference(_lastActivity);
    _quietTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => _evaluate(trigger: 'quiet ${quietSeconds}s'),
    );
  }
  ```
- **验收**: 无效 timer tick 比例从 ~90% 降至 0%（完全事件驱动）
- **风险**: 时间回退边界（系统时间调整），需用 `Stopwatch` 或 `Timer` monotonic 特性
- **测试**: 3 个新 test case — 输出持续重置 timer / 输出停止后触发 / 时间回退安全

#### P1-2: LLM 连续失败快速停止
- **文件**: `lib/services/autopilot_engine.dart`
- **当前**: LLM 失败后 `_beginWaiting()` → 等 30s → 重试，无上限
- **目标**: 新增 `_consecutiveLlmFailures` 计数器，≥3 次自动 `_finish(failed)`
- **验收**: LLM 失败后不等满 quietSeconds 即进入失败状态；UI 显示红色错误卡片而非静默
- **测试**: 2 个新 test case — 连续 3 次失败停止 / 1 次失败后恢复重置计数器

#### P1-3: `_syncRunRecord` 去抖动
- **文件**: `lib/services/autopilot_engine.dart`
- **当前**: 每次 `_addLog` 都调用 `_syncRunRecord`（即使无 record 变化）
- **目标**: 仅在 checklist/status 变更时调用；log 追加不触发
- **实现要点**: 在 `_addLog` 中移除 `_syncRunRecord` 调用，改为在 `_beginWaiting` / `_evaluate`(decision) / `_finish` / `notifyAgentStopped` 中显式调用
- **验收**: `_syncRunRecord` 调用次数从 60-80 次/run 降至 ≤20 次/run

#### P1-4: Panel 组件拆分（机械重构，无行为变更）
- **文件**: `lib/widgets/autopilot_panel.dart` → 多个文件
- **目标**: 
  - `lib/widgets/autopilot/autopilot_panel.dart` — 主 Panel + 布局 (~200 行)
  - `lib/widgets/autopilot/run_info_card.dart` — 运行信息卡片 (~120 行)
  - `lib/widgets/autopilot/settings_dialog.dart` — 设置对话框 (~200 行)
  - `lib/widgets/autopilot/checklist_section.dart` — Checklist 区域 (~100 行)
  - `lib/widgets/autopilot/interactions_section.dart` — LLM 调用查看器 (~200 行)
  - `lib/widgets/autopilot/timeline_section.dart` — 时间线 (~80 行)
  - `lib/widgets/autopilot/history_section.dart` — 历史记录区 (~150 行)
  - `lib/widgets/autopilot/goal_section.dart` — 目标输入区 (~150 行)
  - `lib/widgets/autopilot/record_row.dart` — 记录行 (~100 行)
- **验收**: 无文件超 300 行；所有现有 widget test 通过；无视觉回归

#### P1-5: LLM 层单元测试
- **文件**: 新建 `test/autopilot_llm_test.dart`
- **目标**: ≥80% 覆盖
- **测试范围**:
  - `extractJson` 边界（已有 5 个，补 4 个: 空字符串 / 深层嵌套含 `}` 的字符串值 / Unicode / 超长输入）
  - `AutopilotDecision.fromJson` 边界（已有 2 个，补: 所有字段为 null / 数字类型 itemUpdates key）
  - `AutopilotLlmConfig.isValid` 各种组合
  - `LlmCallException` 携带 transcript
  - `_formatRequest` / `_withExtra` 静态方法
- **验收**: `test/autopilot_llm_test.dart` 存在且 ≥12 个 test case

---

### Phase 2 — 体验增强 + 测试补全（预估 8-10 人天）

#### P2-1: Panel 局部刷新（核心体验优化）
- **文件**: `lib/widgets/autopilot/` 下各组件
- **当前**: 1s ticker + manager listener → `setState(() {})` → 全量重建
- **目标**: 用 `ValueListenableBuilder` 或自建 `Listenable` 拆为独立刷新单元
- **拆分粒度**:
  - Status badge / quiet countdown → 独立 `AnimatedBuilder`（仅 1s ticker 影响）
  - Checklist → 独立 listenable（仅在 step 状态变化时刷新）
  - Timeline → 独立 listenable（仅在 log 追加时刷新）
  - Interactions → 独立 listenable（仅在 LLM 调用完成时刷新）
  - Header running/history count → 独立 listenable
- **实现要点**: Engine 提供细粒度 `ValueNotifier`：
  ```dart
  final statusNotifier = ValueNotifier<AutopilotState>(AutopilotState.idle);
  final checklistNotifier = ValueNotifier<List<ChecklistItem>>([]);
  final logNotifier = ValueNotifier<List<AutopilotLogEntry>>([]);
  final interactionNotifier = ValueNotifier<List<AutopilotInteraction>>([]);
  ```
- **验收**: Flutter DevTools 显示 99th 帧时间 <32ms（有 run 运行时）；`setState` 不再出现在涉及 checklist/timeline 以外 widget 的重建中

#### P2-2: Agent 终端实时预览
- **文件**: 新建 `lib/widgets/autopilot/live_preview_card.dart`
- **功能**: 在 `_runInfoCard` 下方展示最近 5 行终端输出（轮询 `peekOutput`）
- **刷新频率**: 每 1s 一次（复用现有 ticker），仅在 `waitingAgent` 状态下显示
- **验收**: 在 waitingAgent 状态下可看到 agent 最近输出；不影响 panel 滚动位置

#### P2-3: 一键展开 Interactions
- **文件**: `lib/widgets/autopilot/interactions_section.dart`
- **功能**: 
  - "展开全部" / "折叠全部" 按钮
  - 每条 interaction 显示 duration + trigger + 一行 summary（已实现），点击展开
  - "复制全部 transcript" 按钮（复制到剪贴板）
- **验收**: 3 个按钮交互正确；复制内容包含所有 request/response

#### P2-4: 选中锁定（Run 完成后不自动切换）
- **文件**: `lib/services/autopilot_manager.dart`
- **当前**: `_normalizeSelection` 在 `_onEngineChanged` 时自动切到最新 running
- **目标**: 仅在用户未主动选择时自动切换；若用户点击过某个 run，保持选中直到用户切换
- **实现要点**: `_selectedRunId` 增加 `_userSelected` 标志；`_normalizeSelection` 仅在 `!_userSelected` 时生效
- **验收**: 选中一个 run → 它完成 → 仍选中该 run（显示 "已完成" 而非自动跳转）

#### P2-5: Panel Widget 测试补全
- **文件**: `test/autopilot_panel_test.dart`
- **目标**: ≥15 个 widget test
- **必测场景**:
  - LLM 未配置时显示配置提示
  - 点 "新增 Autopilot" 创建新 run
  - 运行中列表显示 running 记录
  - 切换 "运行/历史" tab
  - 历史 "重新开始" 回填表单
  - 设置对话框打开/关闭/保存
  - Checklist 项显示正确状态图标
  - Timeline 滚动到最新
  - Interaction 展开/折叠
  - 停止按钮可用状态
  - 空状态文案
  - Agent 下拉列表选中
  - 表单验证（目标为空时按钮 disabled）
  - Per-task system prompt 输入
- **验收**: `test/autopilot_panel_test.dart` ≥15 个 test case，全部通过

---

### Phase 3 — 智能化 + 持久化完善（预估 6-8 人天）

#### P3-1: Evaluate 输出智能过滤
- **文件**: `lib/services/autopilot_engine.dart`
- **当前**: 直接取 tail 120 行发给 LLM
- **目标**: 发送前过滤：
  - 纯空行 → 合并为单个空行
  - ANSI 残留 → 复用 `AnsiUtils.stripAnsi`
  - 重复提示符行（如连续 3 行相同的 `$` 或 `>`）→ 保留 1 行
  - 纯数字/时间戳行 → 过滤
- **实现要点**: 新建 `_filterOutput(String raw)` 静态方法，unit-testable
- **验收**: 平均每次 evaluate 的 `agentOutput` 从 ~1500 tokens 降至 ≤800 tokens（通过 mock LLM 统计 `decideNext` 传入的 `agentOutput` 长度）

#### P3-2: Interaction Transcript 持久化
- **文件**: `lib/services/autopilot_engine.dart` + `lib/models/autopilot_run_record.dart`
- **目标**: 在 `AutopilotRunRecord` 新增字段 `interactionsSummary` (List)，保存最近 5 次的 {trigger, duration, summary, ok, error}
- **不持久化**: 完整 request/response 文本（可能含 API key 敏感信息）
- **验收**: 关闭 app 再打开，历史记录中可见最近 5 次 LLM 调用的梗概

#### P3-3: Resume 体验增强
- **文件**: `lib/services/autopilot_engine.dart` + `lib/widgets/autopilot/run_info_card.dart`
- **当前**: Resume 是隐式的多步流程（reopen → /resume → engine.resume）
- **目标**:
  - 历史记录 "恢复并继续" 按钮 → 一键自动 reopen + resume
  - Resume 时在 log 中标注 "从会话 #X 恢复，重新评估历史输出"
  - 若历史记录 session 不可用（已关闭/进程不存在），显示明确提示
- **验收**: 已完成 run 可一键 resume；不可恢复的 session 有明确提示

#### P3-4: Per-run 静默参数
- **文件**: `lib/services/autopilot_engine.dart` + `lib/widgets/autopilot/goal_section.dart`
- **当前**: `quietSeconds` / `maxIterations` / `outputTailLines` 均为全局设置
- **目标**: UI 增加 "高级选项" 折叠区，per-run 可覆盖这三个参数（留空则使用全局默认）
- **验收**: 设置全局 quiet=30s，新建 run 时指定 quiet=10s，run 的静默检测为 10s

#### P3-5: E2E Smoke 测试
- **文件**: `patrol_test/autopilot_smoke_test.dart`
- **功能**: 端到端启动 app → 配置 LLM → 创建 Autopilot → 等待 agent 完成 → 查看历史记录
- **验收**: 至少 1 条 patrol e2e test（依赖 mock LLM 或本地 Ollama）

---

## 5. 验收矩阵

| 验收项 | Phase | 测量方法 | 通过标准 |
|---|---|---|---|
| __性能__ | | | |
| 无效 timer tick = 0 | P1 | 引擎内部计数器 | `effectiveTicks / totalTicks >= 0.95` |
| Panel 99th 帧 <32ms | P2 | Flutter DevTools | 运行中 profile 30s，99th <32ms |
| LLM token 降低 ≥40% | P3 | mock LLM 统计 agentOutput 长度 | `(before - after) / before >= 0.4` |
| __工程质量__ | | | |
| 测试/源码比 ≥70% | P1+P2 | `wc -l` 统计 | `test_lines / src_lines >= 0.7` |
| Panel widget test ≥15 | P2 | `grep "test("` 计数 | ≥15 个 test case |
| LLM 层测试 ≥12 | P1 | `grep "test("` 计数 | ≥12 个 test case |
| 无文件超 500 行 | P1 | `wc -l` 各文件 | max ≤500 |
| __用户体验__ | | | |
| 终端实时预览可见 | P2 | 手动验收 | waitingAgent 状态可见最近输出 |
| 一键展开 transcript | P2 | 手动验收 | "展开全部" 按钮存在且功能正常 |
| LLM 失败 3 次停止 | P1 | 单元测试 + 手动 | 连续失败后 state=failed |
| 选中不自动切换 | P2 | 手动验收 | run 完成后选中保留 |
| History 含 interaction | P3 | 手动验收 | 关闭重开后历史记录可见 LLM 调用梗概 |
| Resume 一键完成 | P3 | 手动验收 | 历史→恢复→自动 resume 循环继续 |

---

## 6. 风险与依赖

| 风险 | 影响 | 缓解 |
|---|---|---|
| Panel 拆分导致 import 循环 | P1 阻塞 | 拆分前绘制依赖图；公共类型提到 `models/` |
| `ValueNotifier` 粒度过细导致 listener 泄漏 | P2 内存泄漏 | 所有 notifier 在 `dispose()` 中统一释放；Lint rule `use_dispose` |
| 输出过滤误删有用信息 | P3 决策质量下降 | 过滤规则可配置；提供 `--no-filter` debug 模式 |
| Per-run 参数与全局设置冲突 | P3 用户困惑 | UI 明确标注 "覆盖全局设置" 并显示全局默认值 |
| E2E 测试依赖 PTY 环境 | P3 CI 不稳定 | 先用 mock LLM + mock PTY 跑通，再接入真实环境 |

---

## 7. 评审签名

| 角色 | 姓名 | 日期 | 意见 |
|---|---|---|---|
| 技术负责人 | | | |
| 产品经理 | | | |
| QA 负责人 | | | |

---

> 本方案基于 2026-06-10 全链路代码审计数据制定。所有量化目标均有当前基线值和可验证的测量方法。
