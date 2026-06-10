import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/theme/app_colors.dart';
import 'package:coding_agent_dock/theme/app_terminal_theme.dart';

void main() {
  group('NoBoldTerminalStyle', () {
    const style = NoBoldTerminalStyle(fontSize: 13);

    test('ANSI bold cells render at normal weight', () {
      final bolded = style.toTextStyle(bold: true);
      expect(bolded.fontWeight, FontWeight.normal);
    });

    test('normal cells render at normal weight', () {
      expect(style.toTextStyle().fontWeight, FontWeight.normal);
    });

    test('italic and underline still pass through', () {
      final styled = style.toTextStyle(italic: true, underline: true);
      expect(styled.fontStyle, FontStyle.italic);
      expect(styled.decoration, TextDecoration.underline);
      expect(styled.fontWeight, FontWeight.normal);
    });

    test('copyWith keeps the no-bold behavior', () {
      final copied = style.copyWith(fontSize: 14);
      expect(copied, isA<NoBoldTerminalStyle>());
      expect(copied.toTextStyle(bold: true).fontWeight, FontWeight.normal);
    });
  });

  group('AppTerminalTheme', () {
    test('text style is the no-bold variant at 13px', () {
      expect(AppTerminalTheme.textStyle, isA<NoBoldTerminalStyle>());
      expect(AppTerminalTheme.textStyle.fontSize, 13);
    });

    test('foreground matches the app body text token', () {
      expect(AppTerminalTheme.dark.foreground, AppColors.text400);
      expect(AppTerminalTheme.dark.background, AppColors.bg950);
    });

    test('whites are capped at gray-300 (soft contrast)', () {
      expect(AppTerminalTheme.dark.brightWhite, const Color(0xFFD1D5DB));
      // "white" must be darker than brightWhite — both well below gray-50.
      expect(
        AppTerminalTheme.dark.white.computeLuminance(),
        lessThanOrEqualTo(
            AppTerminalTheme.dark.brightWhite.computeLuminance()),
      );
    });
  });
}
