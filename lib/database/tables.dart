import 'package:drift/drift.dart';

/// Drift table definition for task sessions.
///
/// Each session represents a conversation/interaction with a specific agent CLI.
@DataClassName('TaskSession')
class TaskSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Human-readable session name
  TextColumn get name => text().withLength(min: 1, max: 255)();

  /// The agent CLI id used for this session (e.g. "claude", "codex")
  TextColumn get agentCliId => text().withLength(min: 1, max: 64)();

  /// Session status: running, completed, failed, cancelled
  TextColumn get status => text().withLength(min: 1, max: 32)();

  /// Working directory for the session
  TextColumn get workingDirectory => text().withLength(max: 1024).nullable()();

  /// Optional description / goal of the session
  TextColumn get description => text().withLength(max: 2048).nullable()();

  /// Session creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// Session completion timestamp
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Exit code (null if still running)
  IntColumn get exitCode => integer().nullable()();

  /// Duration in milliseconds
  IntColumn get durationMs => integer().nullable()();

  /// Input prompt / task description
  TextColumn get input => text().withLength(max: 65536).nullable()();

  /// The agent's own session id (e.g. Claude Code session UUID),
  /// used to resume the conversation with `--resume <id>`.
  TextColumn get agentSessionId => text().withLength(max: 64).nullable()();

  /// Output / result summary
  TextColumn get output => text().withLength(max: 65536).nullable()();

  /// User-written annotation / note attached to this session.
  TextColumn get notes => text().withLength(max: 4096).nullable()();

  /// User-assigned color label for visual organization.
  /// Stored as a color name string, e.g. 'red', 'blue', 'green'.
  TextColumn get colorLabel => text().withLength(max: 32).nullable()();

  /// Cluster batch ID — shared UUID among sessions created together via
  /// "Run on all agents". Null for single-agent sessions.
  TextColumn get batchId => text().withLength(max: 64).nullable()();

  /// Parent session ID for relay-chained sessions (created automatically by
  /// the auto-relay pipeline). Null for manually created sessions.
  IntColumn get parentSessionId => integer().nullable()();

  /// Workflow run ID — links this session to a DAG workflow execution.
  /// Null for sessions not part of a workflow.
  TextColumn get workflowRunId => text().withLength(max: 64).nullable()();

  /// Workflow node ID — the WorkflowNode.id within the definition.
  /// Null for sessions not part of a workflow.
  TextColumn get workflowNodeId => text().withLength(max: 64).nullable()();

  /// Custom launch arguments override entered by the user in the new-session
  /// dialog. Semantics:
  ///   - null   → use the agent's auto-generated arguments (default behavior)
  ///   - ""     → launch with no extra flags at all (bare command + prompt)
  ///   - "…"    → use exactly these (shell-tokenized) flags instead of the auto ones
  TextColumn get customArgs => text().withLength(max: 2048).nullable()();
}

/// Drift table definition for workflow run records.
///
/// Each record represents a single execution of a workflow definition.
/// The full definition JSON is snapshotted so historical runs remain
/// viewable even if the definition is later edited or deleted.
@DataClassName('WorkflowRunRecord')
class WorkflowRuns extends Table {
  /// Run UUID (primary key).
  TextColumn get id => text()();

  /// The definition UUID this run was created from.
  TextColumn get definitionId => text().withLength(max: 64)();

  /// Human-readable definition name at launch time.
  TextColumn get definitionName => text().withLength(max: 255)();

  /// Full WorkflowDefinition JSON snapshot at launch time.
  TextColumn get definitionJson => text().withLength(max: 65536)();

  /// Run status: running, completed, failed, cancelled.
  TextColumn get status => text().withLength(max: 32)();

  /// Run start timestamp.
  DateTimeColumn get startedAt => dateTime()();

  /// Run completion timestamp (null while running).
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
