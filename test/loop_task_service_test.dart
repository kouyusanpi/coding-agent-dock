import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/models/loop_task.dart';
import 'package:coding_agent_dock/services/loop_task_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoopTask model', () {
    test('toJson / fromJson round-trips all fields', () {
      const task = LoopTask(
        id: 'abc',
        name: 'My Task',
        agentId: 'claude',
        prompt: 'Write tests',
        loopCount: 5,
        workingDirectory: '/home/proj',
      );
      final json = task.toJson();
      final back = LoopTask.fromJson(json);
      expect(back.id, task.id);
      expect(back.name, task.name);
      expect(back.agentId, task.agentId);
      expect(back.prompt, task.prompt);
      expect(back.loopCount, task.loopCount);
      expect(back.workingDirectory, task.workingDirectory);
    });

    test('toJson omits workingDirectory when null', () {
      const task = LoopTask(
          id: 'x', name: 'n', agentId: 'a', prompt: 'p', loopCount: 1);
      expect(task.toJson().containsKey('workingDirectory'), isFalse);
    });

    test('tryDecode returns null for invalid JSON', () {
      expect(LoopTask.tryDecode('not json'), isNull);
    });

    test('encode / tryDecode round-trip', () {
      const task = LoopTask(
          id: '1', name: 'Test', agentId: 'gemini', prompt: 'go', loopCount: 3);
      final decoded = LoopTask.tryDecode(task.encode());
      expect(decoded?.name, 'Test');
      expect(decoded?.loopCount, 3);
    });

    test('copyWith updates specified fields', () {
      const original = LoopTask(
          id: 'id1', name: 'Old', agentId: 'claude', prompt: 'p', loopCount: 2);
      final updated = original.copyWith(name: 'New', loopCount: 7);
      expect(updated.id, 'id1');
      expect(updated.name, 'New');
      expect(updated.loopCount, 7);
      expect(updated.agentId, 'claude');
    });

    test('copyWith can clear workingDirectory to null', () {
      const task = LoopTask(
          id: 'x', name: 'n', agentId: 'a', prompt: 'p', loopCount: 1,
          workingDirectory: '/some/dir');
      final cleared =
          task.copyWith(workingDirectory: null);
      expect(cleared.workingDirectory, isNull);
    });
  });

  group('LoopTaskService', () {
    test('loadAll returns empty list initially', () async {
      final tasks = await LoopTaskService.loadAll();
      expect(tasks, isEmpty);
    });

    test('create adds a task and loadAll returns it', () async {
      final task = await LoopTaskService.create(
        name: 'Refactor',
        agentId: 'claude',
        prompt: 'Refactor the auth module',
        loopCount: 3,
      );
      expect(task.name, 'Refactor');
      expect(task.loopCount, 3);

      final all = await LoopTaskService.loadAll();
      expect(all.length, 1);
      expect(all.first.id, task.id);
    });

    test('create prepends (newest first)', () async {
      await LoopTaskService.create(
          name: 'First', agentId: 'claude', prompt: 'p1', loopCount: 1);
      await LoopTaskService.create(
          name: 'Second', agentId: 'claude', prompt: 'p2', loopCount: 2);
      final all = await LoopTaskService.loadAll();
      expect(all.first.name, 'Second');
      expect(all.last.name, 'First');
    });

    test('update modifies an existing task in-place', () async {
      final task = await LoopTaskService.create(
          name: 'Old', agentId: 'claude', prompt: 'p', loopCount: 1);
      final updated = task.copyWith(name: 'New', loopCount: 5);
      await LoopTaskService.update(updated);
      final all = await LoopTaskService.loadAll();
      expect(all.length, 1);
      expect(all.first.name, 'New');
      expect(all.first.loopCount, 5);
    });

    test('delete removes a task by id', () async {
      final t1 = await LoopTaskService.create(
          name: 'Keep', agentId: 'claude', prompt: 'p1', loopCount: 1);
      final t2 = await LoopTaskService.create(
          name: 'Delete Me', agentId: 'claude', prompt: 'p2', loopCount: 2);
      await LoopTaskService.delete(t2.id);
      final all = await LoopTaskService.loadAll();
      expect(all.length, 1);
      expect(all.first.id, t1.id);
    });

    test('delete is idempotent for unknown id', () async {
      await LoopTaskService.create(
          name: 'Task', agentId: 'claude', prompt: 'p', loopCount: 1);
      await LoopTaskService.delete('non-existent-id');
      final all = await LoopTaskService.loadAll();
      expect(all.length, 1);
    });

    test('create generates unique ids', () async {
      final t1 = await LoopTaskService.create(
          name: 'A', agentId: 'claude', prompt: 'p', loopCount: 1);
      final t2 = await LoopTaskService.create(
          name: 'B', agentId: 'claude', prompt: 'p', loopCount: 1);
      expect(t1.id, isNot(equals(t2.id)));
    });

    test('tasks with workingDirectory persist and restore it', () async {
      await LoopTaskService.create(
        name: 'Dir Task',
        agentId: 'codex',
        prompt: 'build',
        loopCount: 2,
        workingDirectory: '/home/user/project',
      );
      final all = await LoopTaskService.loadAll();
      expect(all.first.workingDirectory, '/home/user/project');
    });
  });
}
