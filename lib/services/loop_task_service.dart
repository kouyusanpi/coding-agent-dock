import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/loop_task.dart';

/// Persistent CRUD for [LoopTask] records stored in SharedPreferences.
///
/// Each task is encoded as a JSON string and stored as a list under a single
/// key. The list is newest-first: create() inserts at index 0.
class LoopTaskService {
  LoopTaskService._();

  static const _key = 'loop_tasks_v1';
  static const _uuid = Uuid();

  /// Load all saved loop tasks. Returns an empty list on any error.
  static Future<List<LoopTask>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      return raw
          .map(LoopTask.tryDecode)
          .whereType<LoopTask>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Create a new [LoopTask] and persist it. Returns the saved task.
  static Future<LoopTask> create({
    required String name,
    required String agentId,
    required String prompt,
    required int loopCount,
    String? workingDirectory,
  }) async {
    final task = LoopTask(
      id: _uuid.v4(),
      name: name,
      agentId: agentId,
      prompt: prompt,
      loopCount: loopCount,
      workingDirectory: workingDirectory,
    );
    await _upsert(task, prepend: true);
    return task;
  }

  /// Update an existing task in-place. No-op if the id is not found.
  static Future<void> update(LoopTask task) => _upsert(task);

  /// Delete a task by id. Idempotent — does nothing if not found.
  static Future<void> delete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await loadAll();
      final updated = all.where((t) => t.id != id).toList();
      await prefs.setStringList(_key, updated.map((t) => t.encode()).toList());
    } catch (_) {}
  }

  static Future<void> _upsert(LoopTask task, {bool prepend = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await loadAll();
      final idx = all.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        all[idx] = task;
      } else if (prepend) {
        all.insert(0, task);
      } else {
        all.add(task);
      }
      await prefs.setStringList(_key, all.map((t) => t.encode()).toList());
    } catch (_) {}
  }
}
