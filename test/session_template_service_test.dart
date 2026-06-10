import 'package:coding_agent_dock/models/session_template.dart';
import 'package:coding_agent_dock/services/session_template_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SessionTemplateService', () {
    test('load returns empty list when nothing saved', () async {
      final templates = await SessionTemplateService.load();
      expect(templates, isEmpty);
    });

    test('create persists and returns a template with UUID id', () async {
      final t = await SessionTemplateService.create(
        name: 'Fix bug',
        agentId: 'claude',
        prompt: 'Find and fix the null pointer exception',
      );
      expect(t.id, isNotEmpty);
      expect(t.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(t.name, 'Fix bug');
      expect(t.agentId, 'claude');
      expect(t.prompt, 'Find and fix the null pointer exception');
      expect(t.workingDirectory, isNull);
    });

    test('create persists to SharedPreferences and load returns it', () async {
      await SessionTemplateService.create(
        name: 'Write tests',
        agentId: 'aider',
        workingDirectory: '/projects/myapp',
        prompt: 'Add unit tests for the auth module',
      );
      final loaded = await SessionTemplateService.load();
      expect(loaded, hasLength(1));
      expect(loaded.first.name, 'Write tests');
      expect(loaded.first.workingDirectory, '/projects/myapp');
    });

    test('multiple creates accumulate', () async {
      await SessionTemplateService.create(
          name: 'T1', agentId: 'claude', prompt: 'p1');
      await SessionTemplateService.create(
          name: 'T2', agentId: 'gemini', prompt: 'p2');
      final loaded = await SessionTemplateService.load();
      expect(loaded, hasLength(2));
      expect(loaded.map((t) => t.name), containsAll(['T1', 'T2']));
    });

    test('delete removes the template by id', () async {
      final t1 = await SessionTemplateService.create(
          name: 'Keep', agentId: 'claude', prompt: 'stay');
      final t2 = await SessionTemplateService.create(
          name: 'Remove', agentId: 'claude', prompt: 'gone');
      await SessionTemplateService.delete(t2.id);
      final loaded = await SessionTemplateService.load();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, t1.id);
    });

    test('update replaces existing template', () async {
      final original = await SessionTemplateService.create(
          name: 'Old name', agentId: 'claude', prompt: 'old prompt');
      await SessionTemplateService.update(
          original.copyWith(name: 'New name', prompt: 'new prompt'));
      final loaded = await SessionTemplateService.load();
      expect(loaded, hasLength(1));
      expect(loaded.first.name, 'New name');
      expect(loaded.first.prompt, 'new prompt');
    });

    test('update on unknown id is a no-op', () async {
      await SessionTemplateService.create(
          name: 'T', agentId: 'claude', prompt: 'p');
      // Create a template with a fake id to simulate unknown.
      final phantom = SessionTemplate(
        id: 'not-a-real-id',
        name: 'Phantom',
        agentId: 'claude',
        prompt: 'nope',
        createdAt: DateTime(2026),
      );
      await SessionTemplateService.update(phantom);
      final loaded = await SessionTemplateService.load();
      expect(loaded, hasLength(1)); // unchanged
    });

    test('SessionTemplate.fromJson round-trips through toJson', () async {
      final t = await SessionTemplateService.create(
        name: 'RT',
        agentId: 'codex',
        workingDirectory: '/tmp',
        prompt: 'do something',
      );
      final roundTripped = SessionTemplate.fromJson(t.toJson());
      expect(roundTripped.id, t.id);
      expect(roundTripped.name, t.name);
      expect(roundTripped.agentId, t.agentId);
      expect(roundTripped.workingDirectory, t.workingDirectory);
      expect(roundTripped.prompt, t.prompt);
    });
  });
}
