import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/utils/ansi_utils.dart';

void main() {
  group('AnsiUtils.stripAnsi', () {
    test('returns plain text unchanged', () {
      expect(AnsiUtils.stripAnsi('hello world'), 'hello world');
    });

    test('strips SGR color codes', () {
      expect(
        AnsiUtils.stripAnsi('\x1b[31mred\x1b[0m normal'),
        'red normal',
      );
    });

    test('strips bold + color + reset', () {
      expect(
        AnsiUtils.stripAnsi('\x1b[1;32mGreen Bold\x1b[0m'),
        'Green Bold',
      );
    });

    test('strips cursor movement CSI sequences', () {
      expect(
        AnsiUtils.stripAnsi('a\x1b[2Kb'),
        'ab',
      );
    });

    test('strips OSC sequences (window title)', () {
      expect(
        AnsiUtils.stripAnsi('\x1b]0;Terminal Title\x07hello'),
        'hello',
      );
    });

    test('strips OSC with ST terminator', () {
      expect(
        AnsiUtils.stripAnsi('\x1b]2;tab title\x1b\\text'),
        'text',
      );
    });

    test('normalises CR+LF to LF', () {
      expect(AnsiUtils.stripAnsi('a\r\nb'), 'a\nb');
    });

    test('normalises lone CR to LF', () {
      expect(AnsiUtils.stripAnsi('a\rb'), 'a\nb');
    });

    test('collapses 3+ consecutive blank lines to 2', () {
      const input = 'a\n\n\n\n\nb';
      expect(AnsiUtils.stripAnsi(input), 'a\n\nb');
    });

    test('strips realistic Claude Code output', () {
      const input =
          '\x1b[?25l\x1b[2K\x1b[1G\x1b[32m✓\x1b[0m Analyzing code...\r\n'
          '\x1b[1mResult:\x1b[22m All tests pass\r\n';
      final result = AnsiUtils.stripAnsi(input);
      expect(result, contains('Analyzing code...'));
      expect(result, contains('Result:'));
      expect(result, contains('All tests pass'));
      expect(result, isNot(contains('\x1b')));
    });

    test('handles empty input', () {
      expect(AnsiUtils.stripAnsi(''), '');
    });
  });

  group('AnsiUtils.tail', () {
    test('returns text unchanged when shorter than maxChars', () {
      expect(AnsiUtils.tail('hello', maxChars: 100), 'hello');
    });

    test('trims to last maxChars and starts at a line boundary', () {
      final lines = List.generate(20, (i) => 'line $i');
      final text = lines.join('\n');
      final result = AnsiUtils.tail(text, maxChars: 30);
      // Result should not start mid-line.
      expect(result, isNot(startsWith('ine ')));
      expect(result.length, lessThanOrEqualTo(30 + 20));
    });

    test('falls back to character cut when no newline found', () {
      final text = 'a' * 200;
      final result = AnsiUtils.tail(text, maxChars: 100);
      expect(result.length, 100);
    });

    test('handles text exactly at limit', () {
      final text = 'x' * 8000;
      expect(AnsiUtils.tail(text, maxChars: 8000), text);
    });
  });
}
