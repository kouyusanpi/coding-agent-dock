import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claude_code_cli_flutter/database/database.dart';
import 'package:claude_code_cli_flutter/models/agent_cli.dart';
import 'package:claude_code_cli_flutter/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionManager manager;

  final claude = AgentCli(
    id: 'claude',
    displayName: 'Claude Code',
    binaryName: 'claude',
    detected: true,
    binaryPath: '/opt/homebrew/bin/claude',
    lastChecked: DateTime(2026, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    manager = SessionManager(db);
  });

  tearDown(() => db.close());

  group('SessionManager.buildLaunchArgs (claude)', () {
    test('first launch pins a new conversation via --session-id + prompt',
        () async {
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: false,
        prompt: '修复 bug',
      );
      expect(args, [
        '--model', 'opus',
        '--effort', 'high',
        '--session-id', 'abc-123',
        '修复 bug',
      ]);
    });

    test('relaunch resumes the conversation and omits the prompt', () async {
      // The transcript exists → genuine resume.
      manager.claudeSessionExists = (wd, id) => true;
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: true,
        prompt: '修复 bug',
      );
      expect(args, [
        '--model', 'opus',
        '--effort', 'high',
        '--resume', 'abc-123',
      ]);
    });

    test('relaunch falls back to --session-id when no transcript exists',
        () async {
      // First launch failed before Claude persisted the session → resuming
      // would error with "No session found", so register the UUID fresh.
      manager.claudeSessionExists = (wd, id) => false;
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: true,
        prompt: '修复 bug',
      );
      expect(args, [
        '--model', 'opus',
        '--effort', 'high',
        '--session-id', 'abc-123',
        '修复 bug',
      ]);
    });

    test('customArgs override the auto-generated Claude flags', () async {
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: false,
        prompt: '修复 bug',
        customArgs: '--model sonnet --permission-mode plan',
      );
      expect(args, [
        '--model', 'sonnet',
        '--permission-mode', 'plan',
        '--session-id', 'abc-123',
        '修复 bug',
      ]);
    });

    test('empty customArgs drops every flag but keeps session-id + prompt',
        () async {
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: false,
        prompt: '修复 bug',
        customArgs: '',
      );
      expect(args, ['--session-id', 'abc-123', '修复 bug']);
    });

    test('bare launch returns no arguments at all', () async {
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: false,
        prompt: '修复 bug',
        bare: true,
      );
      expect(args, isEmpty);
    });

    test('deniedOptions strips a flag and its value, keeping the rest',
        () async {
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: false,
        prompt: '修复 bug',
        deniedOptions: {'--effort'},
      );
      expect(args, [
        '--model', 'opus',
        '--session-id', 'abc-123',
        '修复 bug',
      ]);
    });

    test('a denied value-less flag adjacent to the prompt never eats it',
        () async {
      // --dangerously-skip-permissions takes no value; stripping it must not
      // consume the positional prompt that follows in the final arg list.
      final args = await manager.buildLaunchArgs(
        claude,
        agentSessionId: 'abc-123',
        resume: false,
        prompt: 'do it',
        customArgs: '--dangerously-skip-permissions',
        deniedOptions: {'--dangerously-skip-permissions'},
      );
      expect(args, ['--session-id', 'abc-123', 'do it']);
    });
  });

  group('SessionManager.buildLaunchArgs (non-claude)', () {
    final codex = AgentCli(
      id: 'codex',
      displayName: 'Codex',
      binaryName: 'codex',
      detected: true,
      binaryPath: '/usr/local/bin/codex',
      lastChecked: DateTime(2026, 1, 1),
    );

    test('no customArgs → bare command + prompt only', () async {
      final args = await manager.buildLaunchArgs(codex, prompt: 'hello');
      expect(args, ['hello']);
    });

    test('customArgs become the only flags, before the prompt', () async {
      final args = await manager.buildLaunchArgs(
        codex,
        prompt: 'hello',
        customArgs: '--full-auto',
      );
      expect(args, ['--full-auto', 'hello']);
    });
  });

  group('SessionManager.tokenizeArgs', () {
    test('splits on whitespace', () {
      expect(SessionManager.tokenizeArgs('--a 1 --b 2'),
          ['--a', '1', '--b', '2']);
    });

    test('honors double and single quotes', () {
      expect(
        SessionManager.tokenizeArgs(
            '--append-system-prompt "be very concise" --x \'a b\''),
        ['--append-system-prompt', 'be very concise', '--x', 'a b'],
      );
    });

    test('collapses runs of whitespace and trims', () {
      expect(SessionManager.tokenizeArgs('   --a    --b  '), ['--a', '--b']);
    });

    test('blank input yields an empty list', () {
      expect(SessionManager.tokenizeArgs(''), isEmpty);
      expect(SessionManager.tokenizeArgs('   '), isEmpty);
    });
  });

  group('SessionManager session lifecycle', () {
    test('createSession generates an agent session UUID for claude',
        () async {
      final id = await manager.createSession(name: 'Test', cli: claude);
      final session = await manager.getSession(id);
      expect(session!.agentSessionId, isNotNull);
      expect(session.agentSessionId,
          matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(session.status, 'created');
    });

    test('markExited persists exit code, status and agent session id',
        () async {
      final id = await manager.createSession(name: 'Test', cli: claude);
      await manager.markExited(id,
          exitCode: 0, durationMs: 1200, agentSessionId: 'abc-123');
      final session = await manager.getSession(id);
      expect(session!.status, 'completed');
      expect(session.exitCode, 0);
      expect(session.agentSessionId, 'abc-123');
    });

    test('markExited records failure for non-zero exit codes', () async {
      final id = await manager.createSession(name: 'Test', cli: claude);
      await manager.markExited(id, exitCode: 1, agentSessionId: 'abc-123');
      final session = await manager.getSession(id);
      expect(session!.status, 'failed');
    });

    test('createSession stores batchId for cluster runs', () async {
      const batch = 'test-batch-uuid';
      final id1 =
          await manager.createSession(name: 'A', cli: claude, batchId: batch);
      final id2 =
          await manager.createSession(name: 'B', cli: claude, batchId: batch);
      final s1 = await manager.getSession(id1);
      final s2 = await manager.getSession(id2);
      expect(s1!.batchId, batch);
      expect(s2!.batchId, batch);
    });

    test('createSession leaves batchId null for solo runs', () async {
      final id = await manager.createSession(name: 'Solo', cli: claude);
      final session = await manager.getSession(id);
      expect(session!.batchId, isNull);
    });

    test('createSession stores parentSessionId for relay-chained sessions',
        () async {
      final parentId = await manager.createSession(name: 'Parent', cli: claude);
      final childId = await manager.createSession(
        name: 'Child',
        cli: claude,
        parentSessionId: parentId,
      );
      final child = await manager.getSession(childId);
      expect(child!.parentSessionId, parentId);
    });

    test('createSession leaves parentSessionId null for non-relay sessions',
        () async {
      final id = await manager.createSession(name: 'Solo', cli: claude);
      final session = await manager.getSession(id);
      expect(session!.parentSessionId, isNull);
    });

    test('getSessionName returns null for missing parent', () async {
      final name = await db.getSessionName(99999);
      expect(name, isNull);
    });

    test('getSessionName returns parent name when it exists', () async {
      final parentId =
          await manager.createSession(name: 'Parent Task', cli: claude);
      final name = await db.getSessionName(parentId);
      expect(name, 'Parent Task');
    });
  });
}
