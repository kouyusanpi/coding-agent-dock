import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

/// Application database using Drift (SQLite).
///
/// Stores task sessions with full relational query support.
@DriftDatabase(tables: [TaskSessions, WorkflowRuns])
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  /// Create a database on a custom executor (e.g. in-memory) for tests.
  AppDatabase.forTesting(super.executor);

  /// Singleton instance.
  static AppDatabase? _instance;

  /// Get or create the database instance.
  ///
  /// Call [initialize] first to set up the database file path.
  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;

    final dbDir = await getApplicationSupportDirectory();
    final dbPath = p.join(dbDir.path, 'agent_cli_manager.db');

    // Ensure the directory exists
    await Directory(dbDir.path).create(recursive: true);

    final db = AppDatabase._(NativeDatabase(File(dbPath)));
    _instance = db;
    return db;
  }

  @override
  int get schemaVersion => 8;

  /// Returns true if [column] exists in [table] (uses PRAGMA table_info).
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  /// Returns true if [table] exists in the database.
  Future<bool> _hasTable(String table) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      variables: [Variable.withString(table)],
    ).get();
    return rows.isNotEmpty;
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          if (!await _hasColumn('task_sessions', 'agent_session_id')) {
            await m.addColumn(taskSessions, taskSessions.agentSessionId);
          }
        }
        if (from < 3) {
          if (!await _hasColumn('task_sessions', 'notes')) {
            await m.addColumn(taskSessions, taskSessions.notes);
          }
        }
        if (from < 4) {
          if (!await _hasColumn('task_sessions', 'color_label')) {
            await m.addColumn(taskSessions, taskSessions.colorLabel);
          }
        }
        if (from < 5) {
          if (!await _hasColumn('task_sessions', 'batch_id')) {
            await m.addColumn(taskSessions, taskSessions.batchId);
          }
        }
        if (from < 6) {
          if (!await _hasColumn('task_sessions', 'parent_session_id')) {
            await m.addColumn(taskSessions, taskSessions.parentSessionId);
          }
        }
        if (from < 7) {
          if (!await _hasColumn('task_sessions', 'workflow_run_id')) {
            await m.addColumn(taskSessions, taskSessions.workflowRunId);
          }
          if (!await _hasColumn('task_sessions', 'workflow_node_id')) {
            await m.addColumn(taskSessions, taskSessions.workflowNodeId);
          }
          if (!await _hasTable('workflow_runs')) {
            await m.createTable(workflowRuns);
          }
        }
        if (from < 8) {
          if (!await _hasColumn('task_sessions', 'custom_args')) {
            await m.addColumn(taskSessions, taskSessions.customArgs);
          }
        }
      },
      beforeOpen: (details) async {
        // Reset sessions left in 'running' state from a previous app crash or
        // forced quit — their PTYs no longer exist so they can never complete.
        await customStatement(
          "UPDATE task_sessions SET status = 'failed', updated_at = ? "
          "WHERE status = 'running'",
          [DateTime.now().millisecondsSinceEpoch ~/ 1000],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Query helpers for TaskSessions
  // ---------------------------------------------------------------------------

  /// Watch all sessions, ordered by most recent first.
  Stream<List<TaskSession>> watchAllSessions() {
    return (select(taskSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Get sessions filtered by agent CLI.
  Future<List<TaskSession>> getSessionsByCli(String cliId) {
    return (select(taskSessions)..where((t) => t.agentCliId.equals(cliId)))
        .get();
  }

  /// Watch sessions filtered by agent CLI.
  Stream<List<TaskSession>> watchSessionsByCli(String cliId) {
    return (select(taskSessions)
          ..where((t) => t.agentCliId.equals(cliId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Get sessions by status.
  Future<List<TaskSession>> getSessionsByStatus(String status) {
    return (select(taskSessions)..where((t) => t.status.equals(status)))
        .get();
  }

  /// Watch all sessions that share a cluster batch ID.
  Stream<List<TaskSession>> watchSessionsByBatch(String batchId) {
    return (select(taskSessions)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Insert a new session and return its id.
  Future<int> createSession(TaskSessionsCompanion entry) {
    return into(taskSessions).insert(entry);
  }

  /// Get a single session by id.
  Future<TaskSession?> getSession(int id) {
    return (select(taskSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Update session status and related fields.
  Future<bool> updateSessionStatus(
    int id,
    String status, {
    int? exitCode,
    int? durationMs,
    String? output,
    String? agentSessionId,
  }) async {
    final rows = await (update(taskSessions)
          ..where((t) => t.id.equals(id)))
        .write(TaskSessionsCompanion(
      status: Value(status),
      updatedAt: Value(DateTime.now()),
      completedAt: status == 'completed' || status == 'failed'
          ? Value(DateTime.now())
          : const Value.absent(),
      exitCode: exitCode != null ? Value(exitCode) : const Value.absent(),
      durationMs:
          durationMs != null ? Value(durationMs) : const Value.absent(),
      output: output != null ? Value(output) : const Value.absent(),
      agentSessionId: agentSessionId != null
          ? Value(agentSessionId)
          : const Value.absent(),
    ));
    return rows > 0;
  }

  /// Return up to [limit] recently used distinct non-empty input prompts.
  Future<List<String>> recentPrompts({int limit = 10}) async {
    final query = selectOnly(taskSessions)
      ..addColumns([taskSessions.input, taskSessions.createdAt])
      ..where(taskSessions.input.isNotNull())
      ..orderBy([OrderingTerm.desc(taskSessions.createdAt)]);

    final rows = await query.get();
    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final input = row.read(taskSessions.input);
      if (input != null && input.trim().isNotEmpty && seen.add(input.trim())) {
        result.add(input.trim());
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  /// Return the most recently used distinct working directories (up to [limit]).
  Future<List<String>> recentWorkingDirectories({int limit = 5}) async {
    final query = selectOnly(taskSessions)
      ..addColumns([taskSessions.workingDirectory, taskSessions.createdAt])
      ..where(taskSessions.workingDirectory.isNotNull())
      ..orderBy([OrderingTerm.desc(taskSessions.createdAt)]);

    final rows = await query.get();
    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final dir = row.read(taskSessions.workingDirectory);
      if (dir != null && dir.isNotEmpty && seen.add(dir)) {
        result.add(dir);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  /// Delete all sessions whose status is not 'running' or 'created'.
  Future<int> deleteFinishedSessions() {
    return (delete(taskSessions)
          ..where((t) =>
              t.status.isNotIn(['running', 'created'])))
        .go();
  }

  /// Rename a session.
  Future<bool> renameSession(int id, String name) async {
    final rows = await (update(taskSessions)..where((t) => t.id.equals(id)))
        .write(TaskSessionsCompanion(
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
    return rows > 0;
  }

  /// Delete a session by id.
  Future<int> deleteSession(int id) {
    return (delete(taskSessions)..where((t) => t.id.equals(id))).go();
  }

  /// Update the user-written notes for a session. Pass null to clear.
  Future<bool> updateSessionNotes(int id, String? notes) async {
    final rows = await (update(taskSessions)..where((t) => t.id.equals(id)))
        .write(TaskSessionsCompanion(
      notes: Value(notes),
      updatedAt: Value(DateTime.now()),
    ));
    return rows > 0;
  }

  /// Update the color label for a session. Pass null to clear.
  Future<bool> updateSessionColorLabel(int id, String? colorLabel) async {
    final rows = await (update(taskSessions)..where((t) => t.id.equals(id)))
        .write(TaskSessionsCompanion(
      colorLabel: Value(colorLabel),
      updatedAt: Value(DateTime.now()),
    ));
    return rows > 0;
  }

  /// Get the name of a session's parent (for relay chain display). Returns null
  /// when [parentId] is null or the parent has been deleted.
  Future<String?> getSessionName(int? parentId) async {
    if (parentId == null) return null;
    final row = await (select(taskSessions)
          ..where((t) => t.id.equals(parentId)))
        .getSingleOrNull();
    return row?.name;
  }

  /// Get session count by agent CLI.
  Future<Map<String, int>> getSessionCountByCli() async {
    final query = selectOnly(taskSessions)
      ..addColumns([taskSessions.agentCliId, taskSessions.id.count()])
      ..groupBy([taskSessions.agentCliId]);

    final rows = await query.get();
    final result = <String, int>{};
    for (final row in rows) {
      final cliId = row.read(taskSessions.agentCliId);
      final count = row.read(taskSessions.id.count()) ?? 0;
      if (cliId != null) result[cliId] = count;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Query helpers for WorkflowRuns
  // ---------------------------------------------------------------------------

  /// Watch all sessions belonging to a workflow run, ordered by creation.
  Stream<List<TaskSession>> watchWorkflowRunSessions(String workflowRunId) {
    return (select(taskSessions)
          ..where((t) => t.workflowRunId.equals(workflowRunId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Get all workflow runs, newest first.
  Future<List<WorkflowRunRecord>> getWorkflowRuns() {
    return (select(workflowRuns)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// Watch all workflow runs, newest first.
  Stream<List<WorkflowRunRecord>> watchWorkflowRuns() {
    return (select(workflowRuns)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  /// Insert a new workflow run record and return its id.
  Future<String> createWorkflowRun(WorkflowRunsCompanion entry) {
    return into(workflowRuns).insertReturning(entry).then((r) => r.id);
  }

  /// Update a workflow run's status and optional completion timestamp.
  Future<bool> updateWorkflowRunStatus(
    String id,
    String status, {
    DateTime? completedAt,
  }) async {
    final rows = await (update(workflowRuns)
          ..where((t) => t.id.equals(id)))
        .write(WorkflowRunsCompanion(
      status: Value(status),
      completedAt: completedAt != null
          ? Value(completedAt)
          : status == 'completed' || status == 'failed' || status == 'cancelled'
              ? Value(DateTime.now())
              : const Value.absent(),
    ));
    return rows > 0;
  }
}
