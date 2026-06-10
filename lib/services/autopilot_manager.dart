import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/autopilot_run_record.dart';
import 'autopilot_engine.dart';
import 'settings_service.dart';

class AutopilotManager extends ChangeNotifier {
  final AutopilotEngine Function() createEngine;

  final List<AutopilotEngine> _engines = [];
  String? _selectedRunId;

  AutopilotManager({required this.createEngine});

  List<AutopilotEngine> get engines => UnmodifiableListView(_engines);

  List<AutopilotEngine> get runningEngines =>
      _engines.where((engine) => engine.isRunning).toList()..sort((a, b) {
        final aTime =
            a.currentRecord?.startedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.currentRecord?.startedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

  List<AutopilotRunRecord> get allRecords {
    final recordsById = <String, AutopilotRunRecord>{};
    for (final record in SettingsService.autopilotRunHistory) {
      recordsById[record.id] = record;
    }
    for (final engine in _engines) {
      final record = engine.currentRecord;
      if (record != null) recordsById[record.id] = record;
    }
    final list = recordsById.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  List<AutopilotRunRecord> get runningRecords => runningEngines
      .map((engine) => engine.currentRecord)
      .whereType<AutopilotRunRecord>()
      .toList();

  List<AutopilotRunRecord> get historyRecords {
    final activeIds = runningRecords.map((r) => r.id).toSet();
    return allRecords
        .where((record) => !activeIds.contains(record.id))
        .toList();
  }

  String? get selectedRunId => _selectedRunId;

  AutopilotEngine? get selectedEngine {
    final id = _selectedRunId;
    if (id == null) return null;
    for (final engine in _engines) {
      if (engine.currentRecord?.id == id) return engine;
    }
    return null;
  }

  AutopilotRunRecord? get selectedRecord {
    final id = _selectedRunId;
    if (id == null) {
      final running = runningRecords;
      if (running.isNotEmpty) return running.first;
      final history = historyRecords;
      return history.isEmpty ? null : history.first;
    }
    for (final record in allRecords) {
      if (record.id == id) return record;
    }
    return null;
  }

  Future<AutopilotEngine> startRun({
    required String goal,
    required String agentId,
    String? workingDirectory,
    String? taskName,
    String? systemPrompt,
  }) async {
    final engine = createEngine();
    engine.addListener(_onEngineChanged);
    _engines.insert(0, engine);
    notifyListeners();

    final future = engine.start(
      goal: goal,
      agentId: agentId,
      workingDirectory: workingDirectory,
      taskName: taskName,
      systemPrompt: systemPrompt,
    );
    final runId = engine.currentRecord?.id;
    if (runId != null) _selectedRunId = runId;
    notifyListeners();

    await future;
    _normalizeSelection();
    notifyListeners();
    return engine;
  }

  /// Resume a finished run on its existing (reopened) session. Spawns a new
  /// engine attached to [record]'s session instead of creating a session.
  Future<AutopilotEngine> resumeRun({
    required AutopilotRunRecord record,
    String? systemPrompt,
  }) async {
    final sessionId = record.sessionId;
    if (sessionId == null) {
      throw ArgumentError('Cannot resume a run without a sessionId');
    }
    final engine = createEngine();
    engine.addListener(_onEngineChanged);
    _engines.insert(0, engine);
    notifyListeners();

    final future = engine.resume(
      sessionId: sessionId,
      goal: record.goal,
      agentId: record.agentId,
      workingDirectory: record.workingDirectory,
      systemPrompt: systemPrompt,
    );
    final runId = engine.currentRecord?.id;
    if (runId != null) _selectedRunId = runId;
    notifyListeners();

    await future;
    _normalizeSelection();
    notifyListeners();
    return engine;
  }

  void selectRun(String runId) {
    if (_selectedRunId == runId) return;
    _selectedRunId = runId;
    notifyListeners();
  }

  void notifyAgentStopped(int sessionId) {
    for (final engine in _engines) {
      engine.notifyAgentStopped(sessionId);
    }
  }

  void _onEngineChanged() {
    _normalizeSelection();
    notifyListeners();
  }

  void _normalizeSelection() {
    final selectedId = _selectedRunId;
    if (selectedId != null &&
        allRecords.any((record) => record.id == selectedId)) {
      return;
    }
    final running = runningRecords;
    if (running.isNotEmpty) {
      _selectedRunId = running.first.id;
      return;
    }
    final history = historyRecords;
    _selectedRunId = history.isEmpty ? null : history.first.id;
  }

  @override
  void dispose() {
    for (final engine in _engines) {
      engine.removeListener(_onEngineChanged);
      engine.dispose();
    }
    _engines.clear();
    super.dispose();
  }
}
