import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'app_colors.dart';

/// TerminalStyle that never bolds: ANSI bold output keeps the normal
/// weight so CLI text matches the app's w400 body typography instead of
/// rendering thick/glaring. xterm's painter passes the cell's bold flag
/// into [toTextStyle]; we drop it here (single override point).
class NoBoldTerminalStyle extends TerminalStyle {
  const NoBoldTerminalStyle({
    super.fontSize,
    super.height,
    super.fontFamily,
    super.fontFamilyFallback,
  });

  @override
  TextStyle toTextStyle({
    Color? color,
    Color? backgroundColor,
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) {
    return super.toTextStyle(
      color: color,
      backgroundColor: backgroundColor,
      bold: false, // never bold — match the app's body weight
      italic: italic,
      underline: underline,
    );
  }

  @override
  TerminalStyle copyWith({
    double? fontSize,
    double? height,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    return NoBoldTerminalStyle(
      fontSize: fontSize ?? this.fontSize,
      height: height ?? this.height,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
    );
  }
}

/// xterm terminal theme derived from the app's Tailwind-based design tokens.
///
/// Contrast is deliberately kept gentle: the default foreground IS the
/// app's body color (text400 / gray-400) and whites top out at gray-300
/// (never gray-200/gray-50) so long terminal sessions read exactly like
/// the rest of the UI instead of glaring against the surface-950
/// background. The ANSI palette uses the Tailwind 400-series for normal
/// colors and slightly muted 300-series brights.
class AppTerminalTheme {
  AppTerminalTheme._();

  static const TerminalTheme dark = TerminalTheme(
    cursor: AppColors.accent400,
    selection: AppColors.accent30,
    foreground: AppColors.text400, // gray-400 — same as app body text
    background: AppColors.bg950,

    // --- Normal ANSI (Tailwind 400-series) ---
    black: Color(0xFF1F2937), // gray-800
    red: Color(0xFFF87171), // red-400
    green: Color(0xFF34D399), // emerald-400
    yellow: Color(0xFFFBBF24), // amber-400
    blue: Color(0xFF60A5FA), // blue-400 (accent)
    magenta: Color(0xFFC084FC), // purple-400
    cyan: Color(0xFF22D3EE), // cyan-400
    white: Color(0xFFB6BCC8), // between gray-300/400 — soft "white"

    // --- Bright ANSI (muted 300-series; whites capped at gray-300) ---
    brightBlack: Color(0xFF6B7280), // gray-500
    brightRed: Color(0xFFFCA5A5), // red-300
    brightGreen: Color(0xFF6EE7B7), // emerald-300
    brightYellow: Color(0xFFFCD34D), // amber-300
    brightBlue: Color(0xFF93C5FD), // blue-300
    brightMagenta: Color(0xFFD8B4FE), // purple-300
    brightCyan: Color(0xFF67E8F9), // cyan-300
    brightWhite: Color(0xFFD1D5DB), // gray-300 — softened from gray-200

    // --- Search ---
    searchHitBackground: Color(0xFFFBBF24), // amber-400
    searchHitBackgroundCurrent: Color(0xFFF59E0B), // amber-500
    searchHitForeground: AppColors.bg950,
  );

  /// Monospace stack matching the app's mono typography, tuned for macOS.
  /// 13px (the comfortable terminal default) with a relaxed 1.4 line
  /// height; [NoBoldTerminalStyle] keeps every cell at normal weight.
  static const TerminalStyle textStyle = NoBoldTerminalStyle(
    fontSize: 13,
    height: 1.4,
    fontFamily: 'Menlo',
    fontFamilyFallback: [
      'Monaco',
      'SF Mono',
      'Consolas',
      'monospace',
    ],
  );
}
