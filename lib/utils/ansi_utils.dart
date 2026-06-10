/// Utilities for stripping ANSI/VT100 escape sequences from terminal output.
///
/// PTY output is full of control sequences (colors, cursor moves, OSC window
/// titles, etc.). Before storing as human-readable text — or passing as
/// context to another AI agent — these must be stripped.
class AnsiUtils {
  AnsiUtils._();

  // Matches the common escape sequence forms found in terminal output:
  //   CSI:  ESC [ <params> <letter>       — colors, cursor movement, etc.
  //   OSC:  ESC ] <text> BEL              — window/tab title, hyperlinks
  //   SS2/SS3, DCS, PM, APC variations via generic ESC <0x40..0x5f>
  //   Lone ESC followed by a single char  — e.g. ESC = / ESC > (keypad mode)
  static final _escSeq = RegExp(
    r'\x1b(?:'
    r'\[[0-9;?<>!]*[A-Za-z@`]'       // CSI: ESC [ params letter
    r'|\][^\x07\x1b]*(?:\x07|\x1b\\)'// OSC: ESC ] ... BEL or ESC backslash
    r'|\(.\|'                         // G0 character set: ESC ( x
    r'\)[.\|'                         // G1 character set: ESC ) x  -- note: ] here would break OSC; use \)
    r'|[PX^_][^\x1b]*\x1b\\'         // DCS, SOS, PM, APC with ST
    r'|[\x40-\x5f]'                   // ESC followed by 0x40–0x5f (Fe sequences)
    r'|\x1b'                          // double ESC
    r')',
  );

  /// Remove all ANSI/VT100 escape sequences from [input].
  ///
  /// Also normalises CR+LF and lone CR to LF, and collapses runs of 3+
  /// blank lines down to 2, so the result is readable plain text.
  static String stripAnsi(String input) {
    return input
        .replaceAll(_escSeq, '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // Box-drawing / TUI chrome glyphs that carry no semantic meaning — borders,
  // separators, block elements, spinner bars.
  static final _boxDrawing = RegExp(
    r'[│┃┆┇┊┋╎╏─━┄┅┈┉╌╍═┌┐└┘├┤┬┴┼╭╮╰╯╔╗╚╝╠╣╦╩╬▏▎▍▌▋▊▉█▕▔▁▂▃▄▅▆▇░▒▓◢◣◤◥]',
  );

  /// Clean raw PTY output into meaningful plain text for LLM context.
  ///
  /// Full-screen TUIs (Claude Code, CodeWhale, …) repaint the whole screen on
  /// every frame, so the raw buffer is dominated by box-drawing borders and
  /// dozens of duplicate frames. This:
  ///   1. strips ANSI escape sequences,
  ///   2. removes box-drawing / TUI chrome characters,
  ///   3. collapses repaint duplicates (keeps each unique line at the position
  ///      of its LAST occurrence — i.e. the most recent screen state),
  ///   4. keeps the last [maxLines] non-empty lines.
  ///
  /// The result is the readable conversation/output the agent actually produced,
  /// suitable for feeding to a supervising LLM.
  static String cleanForContext(String raw, {int maxLines = 120}) {
    final stripped = stripAnsi(raw);
    final lines = <String>[];
    for (final rawLine in stripped.split('\n')) {
      var line = rawLine.replaceAll(_boxDrawing, ' ');
      line = line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
      if (line.isEmpty) continue;
      lines.add(line);
    }
    if (lines.isEmpty) return '';
    // Collapse repeated frames: keep the LAST occurrence of each unique line,
    // preserving the order those last occurrences appear in.
    final lastIndex = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      lastIndex[lines[i]] = i;
    }
    final keptIndices = lastIndex.values.toList()..sort();
    final deduped = [for (final i in keptIndices) lines[i]];
    if (deduped.length <= maxLines) return deduped.join('\n');
    return deduped.sublist(deduped.length - maxLines).join('\n');
  }

  /// Return the last [maxChars] characters of [text], starting at a line
  /// boundary so the result never begins mid-line.
  ///
  /// If [text] is shorter than [maxChars] it is returned as-is.
  static String tail(String text, {int maxChars = 8000}) {
    if (text.length <= maxChars) return text;
    // Find the first newline after the cut point so we keep whole lines.
    final cut = text.length - maxChars;
    final nl = text.indexOf('\n', cut);
    if (nl == -1 || nl >= text.length - 1) {
      return text.substring(cut);
    }
    return text.substring(nl + 1);
  }
}
