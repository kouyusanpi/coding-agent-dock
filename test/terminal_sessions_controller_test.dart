import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/models/agent_cli.dart';
import 'package:claude_code_cli_flutter/services/terminal_sessions_controller.dart';
import 'package:claude_code_cli_flutter/theme/app_colors.dart';
import 'package:claude_code_cli_flutter/widgets/task_panel.dart';

AgentCli _cli() => AgentCli(
      id: 'claude',
      displayName: 'Claude Code',
      binaryName: 'claude',
      lastChecked: DateTime(2026),
    );

ActiveTerminal _terminal({String? agentSessionId, bool launched = false}) {
  return ActiveTerminal(
    sessionId: 1,
    sessionName: 'task',
    cli: _cli(),
    agentSessionId: agentSessionId,
    hasLaunchedBefore: launched,
  );
}

void main() {
  group('ActiveTerminal.effectiveStatus', () {
    test('reports created before any launch', () {
      final t = _terminal();
      expect(t.running, isFalse);
      expect(t.effectiveStatus, 'created');
    });

    test('reports completed after clean exit', () {
      final t = _terminal()..exitCode = 0;
      expect(t.effectiveStatus, 'completed');
    });

    test('reports failed after non-zero exit', () {
      final t = _terminal()..exitCode = 130;
      expect(t.effectiveStatus, 'failed');
    });
  });

  group('ActiveTerminal buffers', () {
    test('terminal buffer accumulates output while not focused', () {
      final t = _terminal();
      t.terminal.write('background output');
      // Buffer retains content independent of any rendering widget.
      expect(t.terminal.buffer.lines.length, greaterThan(0));
    });
  });

  group('broadcast', () {
    test('sendText is a safe no-op when the PTY has exited', () {
      final t = _terminal()..exitCode = 0;
      expect(() => t.sendText('hello\r'), returnsNormally);
    });
  });

  group('statusDotColor', () {
    test('maps every lifecycle status to a design token', () {
      expect(statusDotColor('running'), AppColors.emerald500);
      expect(statusDotColor('completed'), AppColors.accent400);
      expect(statusDotColor('failed'), AppColors.red400);
      expect(statusDotColor('cancelled'), AppColors.text500);
      expect(statusDotColor('created'), AppColors.text400);
    });
  });

  group('looksLikeResumeFailure', () {
    test('matches known Claude resume-failure error text', () {
      expect(
        TerminalSessionsController.looksLikeResumeFailure(
            'Error: No conversation found with session ID: abc-123'),
        isTrue,
      );
      expect(
        TerminalSessionsController.looksLikeResumeFailure(
            'No deferred tool marker found in the resumed session.'),
        isTrue,
      );
      expect(
        TerminalSessionsController.looksLikeResumeFailure('No session found'),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(
        TerminalSessionsController.looksLikeResumeFailure('NO SUCH SESSION'),
        isTrue,
      );
    });

    test('does not match normal output', () {
      expect(
        TerminalSessionsController.looksLikeResumeFailure(
            'Resuming session… ready. How can I help?'),
        isFalse,
      );
    });
  });

  group('looksLikeArgError', () {
    test('matches unknown/invalid option errors', () {
      expect(
        TerminalSessionsController.looksLikeArgError(
            "error: unknown option '--effort'"),
        isTrue,
      );
      expect(
        TerminalSessionsController.looksLikeArgError(
            'Invalid argument: --output-format'),
        isTrue,
      );
      expect(
        TerminalSessionsController.looksLikeArgError(
            'unrecognized option: --foo'),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(
        TerminalSessionsController.looksLikeArgError("UNKNOWN OPTION '--X'"),
        isTrue,
      );
    });

    test('does not match normal output', () {
      expect(
        TerminalSessionsController.looksLikeArgError(
            'Loaded options from config. Ready.'),
        isFalse,
      );
    });
  });

  group('extractRejectedOption', () {
    test('pulls the flag out of a commander.js-style error', () {
      expect(
        TerminalSessionsController.extractRejectedOption(
            "error: unknown option '--effort'"),
        '--effort',
      );
    });

    test('handles short flags and unquoted forms', () {
      expect(
        TerminalSessionsController.extractRejectedOption(
            'unrecognized option: --output-format'),
        '--output-format',
      );
      expect(
        TerminalSessionsController.extractRejectedOption(
            "invalid option '-x'"),
        '-x',
      );
    });

    test('returns null when no flag can be pinpointed', () {
      expect(
        TerminalSessionsController.extractRejectedOption(
            'too many arguments provided'),
        isNull,
      );
    });
  });

  group('ActiveTerminal recovery flags', () {
    test('default to false on a fresh terminal', () {
      final t = _terminal();
      expect(t.launchedWithResume, isFalse);
      expect(t.resumeFallbackTried, isFalse);
      expect(t.resumeErrorSeen, isFalse);
      expect(t.launchedWithArgs, isFalse);
      expect(t.bareFallbackTried, isFalse);
      expect(t.argErrorSeen, isFalse);
      expect(t.rejectedOption, isNull);
      expect(t.deniedOptions, isEmpty);
    });
  });
}
