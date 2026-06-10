import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/skill.dart';

/// Manages Claude Code skill files under a skills root.
///
/// Layout: `<root>/<slug>/SKILL.md`. Two roots are supported:
///   - user (global):   `~/.claude/skills`
///   - project (local): `<workingDirectory>/.claude/skills`
///
/// All operations are file-based and immutable in spirit — reads return
/// [Skill] value objects; writes replace whole files.
class SkillService {
  SkillService._();

  static const skillFileName = 'SKILL.md';

  /// The global skills directory (`~/.claude/skills`).
  static String userSkillsRoot() {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, '.claude', 'skills');
  }

  /// A project's skills directory (`<wd>/.claude/skills`).
  static String projectSkillsRoot(String workingDirectory) =>
      p.join(workingDirectory, '.claude', 'skills');

  static String rootFor(SkillScope scope, {String? workingDirectory}) =>
      switch (scope) {
        SkillScope.user => userSkillsRoot(),
        SkillScope.project =>
          projectSkillsRoot(workingDirectory ?? Directory.current.path),
      };

  /// List skills under a root directory, sorted by name. Missing roots and
  /// unreadable files are skipped silently (returns what it can).
  static Future<List<Skill>> list(SkillScope scope,
      {String? workingDirectory}) async {
    final rootPath = rootFor(scope, workingDirectory: workingDirectory);
    final root = Directory(rootPath);
    if (!await root.exists()) return [];

    final skills = <Skill>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final slug = p.basename(entry.path);
      final file = File(p.join(entry.path, skillFileName));
      if (!await file.exists()) continue;
      try {
        final content = await file.readAsString();
        skills.add(Skill.parse(
          content,
          slug: slug,
          path: file.path,
          scope: scope,
        ));
      } catch (_) {
        // Skip unreadable / malformed skill files.
      }
    }
    skills.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return skills;
  }

  /// List both user and (optionally) project skills together.
  static Future<List<Skill>> listAll({String? workingDirectory}) async {
    final user = await list(SkillScope.user);
    final project = (workingDirectory != null && workingDirectory.isNotEmpty)
        ? await list(SkillScope.project, workingDirectory: workingDirectory)
        : <Skill>[];
    return [...user, ...project];
  }

  /// True if a skill directory with [slug] already exists in [scope].
  static Future<bool> exists(String slug, SkillScope scope,
      {String? workingDirectory}) async {
    final dir = p.join(
        rootFor(scope, workingDirectory: workingDirectory), slug, skillFileName);
    return File(dir).exists();
  }

  /// Create a new skill, returning the persisted [Skill]. Throws [StateError]
  /// if a skill with the same slug already exists in the target scope.
  static Future<Skill> create({
    required String name,
    required String description,
    required String body,
    SkillScope scope = SkillScope.user,
    String? workingDirectory,
  }) async {
    final slug = Skill.slugify(name);
    final rootPath = rootFor(scope, workingDirectory: workingDirectory);
    final file = File(p.join(rootPath, slug, skillFileName));
    if (await file.exists()) {
      throw StateError('A skill named "$slug" already exists.');
    }
    final skill = Skill(
      name: name.trim(),
      description: description.trim(),
      body: body,
      path: file.path,
      slug: slug,
      scope: scope,
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(skill.toMarkdown());
    return skill;
  }

  /// Overwrite an existing skill's SKILL.md with the (edited) [skill] content.
  static Future<void> save(Skill skill) async {
    final file = File(skill.path);
    await file.parent.create(recursive: true);
    await file.writeAsString(skill.toMarkdown());
  }

  /// Delete a skill's whole directory.
  static Future<void> delete(Skill skill) async {
    final dir = File(skill.path).parent;
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
