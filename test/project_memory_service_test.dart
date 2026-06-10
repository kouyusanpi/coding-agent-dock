import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:claude_code_cli_flutter/services/project_memory_service.dart';

void main() {
  group('memoryFileNameFor', () {
    test('maps known CLIs to their native memory files', () {
      expect(ProjectMemoryService.memoryFileNameFor('claude'), 'CLAUDE.md');
      expect(ProjectMemoryService.memoryFileNameFor('codex'), 'AGENTS.md');
      expect(ProjectMemoryService.memoryFileNameFor('gemini'), 'GEMINI.md');
    });

    test('maps CLIs with distinct native conventions', () {
      expect(ProjectMemoryService.memoryFileNameFor('gh-copilot'),
          '.github/copilot-instructions.md');
      expect(ProjectMemoryService.memoryFileNameFor('windsurf'),
          '.windsurfrules');
      expect(ProjectMemoryService.memoryFileNameFor('goose'), '.goosehints');
    });

    test('falls back to AGENTS.md for unknown CLIs', () {
      expect(ProjectMemoryService.memoryFileNameFor('aider'), 'AGENTS.md');
      expect(ProjectMemoryService.memoryFileNameFor('whatever'), 'AGENTS.md');
    });
  });

  group('injectSharedBlock', () {
    test('seeds an empty file with a single managed block', () {
      final out = ProjectMemoryService.injectSharedBlock('', 'hello world');
      expect(out.contains(ProjectMemoryService.startMarker), isTrue);
      expect(out.contains(ProjectMemoryService.endMarker), isTrue);
      expect(out.contains('hello world'), isTrue);
    });

    test('preserves existing user content when appending', () {
      const existing = '# My Project\n\nSome rules here.\n';
      final out = ProjectMemoryService.injectSharedBlock(existing, 'shared note');
      expect(out.startsWith('# My Project'), isTrue);
      expect(out.contains('Some rules here.'), isTrue);
      expect(out.contains('shared note'), isTrue);
    });

    test('is idempotent — re-running with same content yields same output', () {
      const existing = '# Header\n';
      final once = ProjectMemoryService.injectSharedBlock(existing, 'memo');
      final twice = ProjectMemoryService.injectSharedBlock(once, 'memo');
      expect(twice, once);
    });

    test('replaces the managed block in place, not duplicating it', () {
      const existing = '# Header\n';
      final first = ProjectMemoryService.injectSharedBlock(existing, 'old memo');
      final second = ProjectMemoryService.injectSharedBlock(first, 'new memo');
      expect(second.contains('new memo'), isTrue);
      expect(second.contains('old memo'), isFalse);
      // Only one managed block.
      expect(ProjectMemoryService.startMarker.allMatches(second).length, 1);
      expect(second.split(ProjectMemoryService.startMarker).length - 1, 1);
    });

    test('blank shared content removes an existing block but keeps user text',
        () {
      const existing = '# Header\n\nkeep me\n';
      final withBlock =
          ProjectMemoryService.injectSharedBlock(existing, 'temp');
      final cleared = ProjectMemoryService.injectSharedBlock(withBlock, '   ');
      expect(cleared.contains(ProjectMemoryService.startMarker), isFalse);
      expect(cleared.contains('keep me'), isTrue);
      expect(cleared.contains('# Header'), isTrue);
    });

    test('does not mutate the input string (immutability)', () {
      const existing = '# Header\n';
      ProjectMemoryService.injectSharedBlock(existing, 'memo');
      expect(existing, '# Header\n');
    });
  });

  group('syncForCli', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('agentdock_pm_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<void> writeShared(String content) async {
      final f = File(p.join(tmp.path, '.agentdock', 'shared-memory.md'));
      await f.parent.create(recursive: true);
      await f.writeAsString(content);
    }

    test('no shared file → no-op, no native file created', () async {
      final wrote = await ProjectMemoryService.syncForCli(
        workingDirectory: tmp.path,
        cliId: 'claude',
      );
      expect(wrote, isFalse);
      expect(File(p.join(tmp.path, 'CLAUDE.md')).existsSync(), isFalse);
    });

    test('blank shared file → no-op', () async {
      await writeShared('   \n');
      final wrote = await ProjectMemoryService.syncForCli(
        workingDirectory: tmp.path,
        cliId: 'claude',
      );
      expect(wrote, isFalse);
    });

    test('writes the shared block into the agent native file', () async {
      await writeShared('Team convention: use tabs.');
      final wrote = await ProjectMemoryService.syncForCli(
        workingDirectory: tmp.path,
        cliId: 'claude',
      );
      expect(wrote, isTrue);
      final content =
          await File(p.join(tmp.path, 'CLAUDE.md')).readAsString();
      expect(content.contains('Team convention: use tabs.'), isTrue);
    });

    test('different agents get their own native file', () async {
      await writeShared('shared ctx');
      await ProjectMemoryService.syncForCli(
          workingDirectory: tmp.path, cliId: 'codex');
      await ProjectMemoryService.syncForCli(
          workingDirectory: tmp.path, cliId: 'gemini');
      expect(File(p.join(tmp.path, 'AGENTS.md')).existsSync(), isTrue);
      expect(File(p.join(tmp.path, 'GEMINI.md')).existsSync(), isTrue);
    });

    test('preserves pre-existing native file content', () async {
      final claudeMd = File(p.join(tmp.path, 'CLAUDE.md'));
      await claudeMd.writeAsString('# Existing rules\n\nDo not delete me.\n');
      await writeShared('appended shared');
      await ProjectMemoryService.syncForCli(
          workingDirectory: tmp.path, cliId: 'claude');
      final content = await claudeMd.readAsString();
      expect(content.contains('Do not delete me.'), isTrue);
      expect(content.contains('appended shared'), isTrue);
    });

    test('second identical sync is a no-op (returns false)', () async {
      await writeShared('stable content');
      final first = await ProjectMemoryService.syncForCli(
          workingDirectory: tmp.path, cliId: 'claude');
      final second = await ProjectMemoryService.syncForCli(
          workingDirectory: tmp.path, cliId: 'claude');
      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('empty working directory → no-op', () async {
      final wrote = await ProjectMemoryService.syncForCli(
        workingDirectory: '   ',
        cliId: 'claude',
      );
      expect(wrote, isFalse);
    });

    test('creates nested parent dir for Copilot convention', () async {
      await writeShared('copilot ctx');
      final wrote = await ProjectMemoryService.syncForCli(
        workingDirectory: tmp.path,
        cliId: 'gh-copilot',
      );
      expect(wrote, isTrue);
      final f =
          File(p.join(tmp.path, '.github', 'copilot-instructions.md'));
      expect(f.existsSync(), isTrue);
      expect((await f.readAsString()).contains('copilot ctx'), isTrue);
    });
  });

  group('readShared / writeShared', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('agentdock_pm_rw');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('readShared returns empty string when file is missing', () async {
      expect(await ProjectMemoryService.readShared(tmp.path), '');
    });

    test('writeShared then readShared round-trips, creating .agentdock',
        () async {
      await ProjectMemoryService.writeShared(tmp.path, 'hello memory');
      expect(File(p.join(tmp.path, '.agentdock', 'shared-memory.md'))
          .existsSync(), isTrue);
      expect(await ProjectMemoryService.readShared(tmp.path), 'hello memory');
    });

    test('writeShared refreshes EXISTING native files only', () async {
      // CLAUDE.md exists, AGENTS.md does not.
      final claudeMd = File(p.join(tmp.path, 'CLAUDE.md'));
      await claudeMd.writeAsString('# Rules\n');

      await ProjectMemoryService.writeShared(tmp.path, 'propagate me');

      expect((await claudeMd.readAsString()).contains('propagate me'), isTrue);
      // AGENTS.md was not pre-existing → not created.
      expect(File(p.join(tmp.path, 'AGENTS.md')).existsSync(), isFalse);
    });

    test('writeShared with blank content clears the block in native files',
        () async {
      final claudeMd = File(p.join(tmp.path, 'CLAUDE.md'));
      await claudeMd.writeAsString('# Rules\n');
      await ProjectMemoryService.writeShared(tmp.path, 'temp ctx');
      expect((await claudeMd.readAsString()).contains('temp ctx'), isTrue);

      await ProjectMemoryService.writeShared(tmp.path, '');
      final after = await claudeMd.readAsString();
      expect(after.contains('temp ctx'), isFalse);
      expect(after.contains(ProjectMemoryService.startMarker), isFalse);
      expect(after.contains('# Rules'), isTrue);
    });
  });
}
