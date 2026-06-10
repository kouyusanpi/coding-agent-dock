# AgentDock

A Flutter desktop app for managing, running, and coordinating multiple local AI coding agent CLIs in a single unified workspace. Supports **macOS** (primary), **Linux**, and **Windows**.

> Bundle: `AgentDock.app` · Identifier: `com.plugins.coding_agent_dock` · Flutter 3.x · macOS 10.15+ / Linux / Windows 10+

---

## Overview

AgentDock detects every AI coding agent CLI installed on your machine, lets you run concurrent task sessions in embedded PTY terminals, and provides a cluster coordination layer so agents can communicate, share state, and hand off work to each other — all without leaving the app.

---

## Supported Agents

| Agent | Provider | Install |
|---|---|---|
| Claude Code | Anthropic | `npm i -g @anthropic-ai/claude-code` |
| OpenAI Codex CLI | OpenAI | `npm i -g @openai/codex` |
| Gemini CLI | Google | `npm i -g @google/gemini-cli` |
| GitHub Copilot | GitHub | `brew install gh && gh extension install github/gh-copilot` |
| Aider | Aider-AI | `pip install aider-install && aider-install` |
| Amazon Q Developer | AWS | `brew install amazon-q` |
| Goose | Block | install script from GitHub |
| Plandex | Plandex AI | install script from plandex.ai |
| Amp | Sourcegraph | `npm i -g @sourcegraph/amp` |
| Open Interpreter | — | `pip install open-interpreter` |
| GPT Engineer | — | `pip install gpt-engineer` |
| Cursor CLI | Cursor | enable from Cursor app |
| Windsurf | Codeium | windsurf.com |
| Continue CLI | Continue | `npm i -g @continuedev/cli` |
| CodeWhale | — | `cargo install codewhale` |

Custom CLIs can be added in the app — any binary on your PATH works.

---

## Features

### Terminal Management

- **Concurrent sessions** — run multiple agents simultaneously in independent PTY terminals with xterm rendering
- **Claude session resume** — every Claude session gets a UUID; the app automatically passes `--session-id` on first launch and `--resume` on reopens, preserving conversation context across restarts
- **Live status dots** — per-session indicators (running / completed / failed / cancelled) update in real time
- **Session pinning** — pin frequently-used sessions to the top of the list
- **Sort & filter** — sort by name, date, or status; filter by agent type or running state

### Project Grouping & Shared Memory

- Sessions are grouped by working directory, giving each project its own visual cluster
- **Shared memory file** — create `.agentdock/shared-memory.md` in a project directory; AgentDock syncs its contents into each agent's native memory file (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) inside a managed block, so every agent in the same project shares the same context
- Live sync polls running sessions every 5 s and re-injects if the file changed
- **Status dot** — a green indicator on the project group header shows at a glance whether shared memory is active for that project
- **Shared Memory editor** — click the brain icon on any project group to view or edit the shared memory file directly from the app

### Cluster IPC API

Every spawned PTY receives three environment variables:

```
AGENTDOCK_API_BASE    = http://127.0.0.1:<port>/v1
AGENTDOCK_IPC_URL     = http://127.0.0.1:<port>/v1/sessions/<id>/events
AGENTDOCK_SESSION_ID  = <sessionId>
AGENTDOCK_HELPERS     = ~/.agentdock/helpers.sh
```

Agents can `source "$AGENTDOCK_HELPERS"` in a Claude Code hook or shell script to get a set of ready-made bash functions:

| Function | Description |
|---|---|
| `agentdock_list` | List all sessions (JSON) |
| `agentdock_status SESSION_ID` | Get a single session's status |
| `agentdock_wait SESSION_ID [TIMEOUT] [POLL]` | Block until a session finishes |
| `agentdock_output SESSION_ID [MAX_LINES]` | Read the last N lines of a session's output |
| `agentdock_stream SESSION_ID` | Stream live output (SSE) |
| `agentdock_inject SESSION_ID "message"` | Write text into another agent's stdin |
| `agentdock_notify [TYPE] [DATA_JSON]` | Post an event to this session's endpoint |
| `agentdock_running_ids` | Print IDs of all running sessions |
| `agentdock_broadcast "message"` | Send a message to all other running sessions |
| `agentdock_kv_get KEY` | Read a value from the shared KV store |
| `agentdock_kv_set KEY VALUE [TTL_SECONDS]` | Write a value (optional auto-expiry TTL) |
| `agentdock_kv_del KEY` | Delete a key |
| `agentdock_kv_list` | List all live keys |

The **shared KV store** (`GET/POST/DELETE /v1/kv/:key`) is an in-memory store that persists for the lifetime of AgentDock. Use it to pass structured state between agents without touching the filesystem — values can carry an optional TTL so they auto-expire.

### Auto-Relay Pipeline

Chain sessions together: hover a running session and set a "chain-to" agent. When the session exits with code 0, AgentDock immediately opens a new session for the chained agent in the same working directory — zero-click handoff between Claude Code → Codex → any other agent.

### Cluster Comparison

Run the same prompt on multiple agents at once ("Run on all") and compare their outputs side by side in the **Cluster Comparison Dialog**. Sessions in the same batch share a `batchId` so the comparison panel always groups them correctly.

### Arg-Error Self-Healing

If a session exits with an "unknown option" error (common when CLI flags change across versions), AgentDock:
1. Parses the rejected flag from the error output
2. Strips just that flag from future launches and persists it per CLI in settings
3. Automatically relaunches — no user interaction needed

Denied flags are cleared automatically when a newer version of the CLI is detected.

### Custom Launch Arguments

The new-session dialog has a **Custom launch arguments** toggle. Enter raw CLI flags (quote-aware tokenization) or leave blank for a bare command with no flags. Override or extend the auto-generated flag set for any session.

### Event Log

A chronological ring-buffer (last 200 events) tracks every significant cluster event: session starts/stops, IPC notifications, pipeline relays, watchdog retries, memory syncs. Open it with `⇧⌘L` or from the Settings drawer.

### CLI Detection Diagnostics

When a CLI is not found, the install dialog shows every path that was searched (common paths + full PATH scan) so you can see exactly why detection failed. A one-click copy button on the install hint makes it easy to run the correct install command.

---

## Build & Run

```bash
# Run in development
flutter run -d macos

# Static analysis
flutter analyze

# All tests (321 tests)
flutter test

# Regenerate Drift ORM code (after editing tables.dart or database.dart)
dart run build_runner build --delete-conflicting-outputs

# Regenerate localizations (after editing lib/l10n/*.arb)
flutter gen-l10n

# Package a release build → dist/AgentDock-<version>.{app,zip,dmg}
scripts/package_app.sh
```

### macOS: Universal Binary Note

The macOS build ships as a universal binary (arm64 + x86_64, macOS 10.15+). `pubspec.yaml` pins `path_provider_foundation: 2.4.4` — do not bump past 2.4.x until Flutter ships multi-arch native-assets for macOS, or Intel builds will break. `scripts/package_app.sh` enforces this by failing if any bundled framework is missing x86_64.

### macOS: App Sandbox

The App Sandbox is **deliberately disabled** in both entitlements files — the app must exec local CLI binaries and spawn PTYs. Do not re-enable it.

### Linux / Windows

Both platforms include platform directories and Flutter's PTY support works on all three desktops. Primary development and QA is on macOS; Linux and Windows builds are community-supported.

---

## Architecture

```
CliRegistry          static list of known CLIs + detection metadata
    ↓
CliDetector          locate binary (which → commonPaths → PATH scan)
    ↓
CliCacheService      JSON file cache of detection results
    ↓
HomeScreen           single-page workspace (sidebar + terminal pane)
    ↓
NewSessionDialog     per-session config (agent, prompt, working dir, custom args)
    ↓
SessionManager       creates DB record, builds CLI flags (Claude settings → flags,
                     custom args, denied flags stripped)
    ↓
TerminalSessionsController   owns all concurrent PTYs (flutter_pty + xterm)
    ↓
AppDatabase (Drift/SQLite)   persists sessions, status, custom args
```

**Storage tiers — do not mix:**

| Tier | Service | Contents |
|---|---|---|
| SharedPreferences | `SettingsService`, `ClaudeSettingsService` | UI prefs, per-CLI settings, denied flags |
| JSON file | `CliCacheService` | CLI detection results (non-critical) |
| SQLite (Drift) | `AppDatabase` | Task sessions, status, history |

**IPC flow:** `IpcServer` binds to a random localhost port on startup; all PTYs receive the port as `AGENTDOCK_API_BASE`. Events posted by agents arrive as a broadcast stream consumed by `HomeScreen._onIpcEvent`.

---

## Directory Structure

```
lib/
├── database/         Drift schema + migrations (schema v8)
├── l10n/             Localizations (en + zh)
├── models/           AgentCli, CliRegistry, TaskSession
├── screens/          HomeScreen, NewSessionDialog
├── services/         Detection, sessions, IPC, KV, memory sync, workflows
├── theme/            AppColors, AppTypography, AppSpacing
├── utils/            ANSI stripping, shell tokenizer
└── widgets/          TaskPanel, TerminalPane, dialogs
```

---

## Localization

UI strings are in `lib/l10n/app_en.arb` (English) and `lib/l10n/app_zh.arb` (Chinese). Add new strings to both files, then run `flutter gen-l10n`.

---

