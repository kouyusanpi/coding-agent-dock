import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:coding_agent_dock/models/skill.dart';
import 'package:coding_agent_dock/services/skill_service.dart';

void main() {
  group('Skill.parse', () {
    test('extracts name + description from frontmatter', () {
      const md = '''---
name: code-review
description: Review code for bugs and style.
---

# Code Review

Body content here.''';
      final skill = Skill.parse(md,
          slug: 'code-review', path: '/x/SKILL.md', scope: SkillScope.user);
      expect(skill.name, 'code-review');
      expect(skill.description, 'Review code for bugs and style.');
      expect(skill.body.trim(), startsWith('# Code Review'));
    });

    test('falls back to slug when frontmatter has no name', () {
      const md = '''---
description: No name here.
---
Body.''';
      final skill = Skill.parse(md,
          slug: 'my-slug', path: '/x/SKILL.md', scope: SkillScope.user);
      expect(skill.name, 'my-slug');
      expect(skill.description, 'No name here.');
    });

    test('handles a document with no frontmatter', () {
      const md = '# Just a heading\n\nNo frontmatter.';
      final skill = Skill.parse(md,
          slug: 'plain', path: '/x/SKILL.md', scope: SkillScope.user);
      expect(skill.name, 'plain');
      expect(skill.description, '');
      expect(skill.body, contains('Just a heading'));
    });

    test('toMarkdown round-trips through parse', () {
      final original = Skill(
        name: 'round-trip',
        description: 'desc with: a colon',
        body: '# Title\n\nLine one.',
        path: '/x/SKILL.md',
        slug: 'round-trip',
        scope: SkillScope.user,
      );
      final reparsed = Skill.parse(original.toMarkdown(),
          slug: 'round-trip', path: '/x/SKILL.md', scope: SkillScope.user);
      expect(reparsed.name, original.name);
      expect(reparsed.description, original.description);
      expect(reparsed.body.trim(), original.body.trim());
    });
  });

  group('Skill.slugify', () {
    test('lowercases and hyphenates', () {
      expect(Skill.slugify('My Cool Skill'), 'my-cool-skill');
    });
    test('strips punctuation and edge hyphens', () {
      expect(Skill.slugify('  Review (code)!  '), 'review-code');
    });
    test('never returns empty', () {
      expect(Skill.slugify('!!!'), 'skill');
    });
  });

  group('SkillService (project scope, temp dir)', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('agentdock_skill_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('create writes SKILL.md and list reads it back', () async {
      final created = await SkillService.create(
        name: 'Test Skill',
        description: 'A test.',
        body: '# Test\n\nDo the thing.',
        scope: SkillScope.project,
        workingDirectory: tmp.path,
      );
      expect(created.slug, 'test-skill');
      expect(
        File(p.join(tmp.path, '.claude', 'skills', 'test-skill', 'SKILL.md'))
            .existsSync(),
        isTrue,
      );

      final listed = await SkillService.list(SkillScope.project,
          workingDirectory: tmp.path);
      expect(listed, hasLength(1));
      expect(listed.first.name, 'Test Skill');
      expect(listed.first.description, 'A test.');
    });

    test('create throws when slug already exists', () async {
      await SkillService.create(
        name: 'Dup',
        description: 'first',
        body: 'a',
        scope: SkillScope.project,
        workingDirectory: tmp.path,
      );
      expect(
        () => SkillService.create(
          name: 'dup',
          description: 'second',
          body: 'b',
          scope: SkillScope.project,
          workingDirectory: tmp.path,
        ),
        throwsStateError,
      );
    });

    test('save overwrites the body', () async {
      final s = await SkillService.create(
        name: 'Editable',
        description: 'v1',
        body: 'original',
        scope: SkillScope.project,
        workingDirectory: tmp.path,
      );
      await SkillService.save(s.copyWith(description: 'v2', body: 'updated'));

      final listed = await SkillService.list(SkillScope.project,
          workingDirectory: tmp.path);
      expect(listed.first.description, 'v2');
      expect(listed.first.body.trim(), 'updated');
    });

    test('delete removes the skill directory', () async {
      final s = await SkillService.create(
        name: 'Gone',
        description: 'x',
        body: 'x',
        scope: SkillScope.project,
        workingDirectory: tmp.path,
      );
      await SkillService.delete(s);
      final listed = await SkillService.list(SkillScope.project,
          workingDirectory: tmp.path);
      expect(listed, isEmpty);
    });

    test('list returns empty for a missing skills root', () async {
      final listed = await SkillService.list(SkillScope.project,
          workingDirectory: p.join(tmp.path, 'nope'));
      expect(listed, isEmpty);
    });

    test('list is sorted by name', () async {
      for (final n in ['Zebra', 'apple', 'Mango']) {
        await SkillService.create(
          name: n,
          description: '',
          body: 'b',
          scope: SkillScope.project,
          workingDirectory: tmp.path,
        );
      }
      final listed = await SkillService.list(SkillScope.project,
          workingDirectory: tmp.path);
      expect(listed.map((s) => s.name), ['apple', 'Mango', 'Zebra']);
    });
  });
}
