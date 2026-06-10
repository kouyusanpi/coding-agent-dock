/// Where a skill lives — global (`~/.claude/skills`) or inside a project.
enum SkillScope { user, project }

/// A Claude Code "skill": a directory `<root>/<slug>/SKILL.md` whose YAML
/// frontmatter carries `name` + `description`, followed by a markdown body.
///
/// This is an immutable value type — edits return a new instance via
/// [copyWith]; persistence lives in `SkillService`.
class Skill {
  /// Display name (frontmatter `name:`, falling back to the directory slug).
  final String name;

  /// One-line description (frontmatter `description:`) — what the skill does
  /// and when it triggers.
  final String description;

  /// Markdown body after the frontmatter block.
  final String body;

  /// Absolute path to the skill's `SKILL.md`.
  final String path;

  /// Directory slug (the folder name under the skills root).
  final String slug;

  final SkillScope scope;

  const Skill({
    required this.name,
    required this.description,
    required this.body,
    required this.path,
    required this.slug,
    required this.scope,
  });

  Skill copyWith({String? name, String? description, String? body}) => Skill(
        name: name ?? this.name,
        description: description ?? this.description,
        body: body ?? this.body,
        path: path,
        slug: slug,
        scope: scope,
      );

  /// Serialize back to a full `SKILL.md` document (frontmatter + body).
  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('name: $name')
      ..writeln('description: $description')
      ..writeln('---')
      ..writeln();
    buf.write(body.trimRight());
    buf.writeln();
    return buf.toString();
  }

  /// Parse a `SKILL.md` document. [slug]/[path]/[scope] come from the file's
  /// location. Missing frontmatter falls back to the slug as the name.
  factory Skill.parse(
    String content, {
    required String slug,
    required String path,
    required SkillScope scope,
  }) {
    var name = slug;
    var description = '';
    var body = content;

    final fm = _frontmatter(content);
    if (fm != null) {
      name = fm.fields['name']?.trim().isNotEmpty == true
          ? fm.fields['name']!.trim()
          : slug;
      description = fm.fields['description']?.trim() ?? '';
      body = fm.body;
    }

    return Skill(
      name: name,
      description: description,
      body: body.trimLeft(),
      path: path,
      slug: slug,
      scope: scope,
    );
  }

  /// Extract a leading `--- ... ---` frontmatter block. Returns null when the
  /// document has no frontmatter. Only simple `key: value` lines are parsed.
  static ({Map<String, String> fields, String body})? _frontmatter(
      String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---')) return null;
    // Find the closing delimiter on its own line.
    final lines = normalized.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') return null;
    var end = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        end = i;
        break;
      }
    }
    if (end == -1) return null;

    final fields = <String, String>{};
    for (var i = 1; i < end; i++) {
      final line = lines[i];
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      if (key.isNotEmpty) fields[key] = value;
    }
    final body = lines.sublist(end + 1).join('\n');
    return (fields: fields, body: body);
  }

  /// Convert an arbitrary display name to a safe directory slug.
  static String slugify(String input) {
    final lower = input.trim().toLowerCase();
    final slug = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'skill' : slug;
  }
}
