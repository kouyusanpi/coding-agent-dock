import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// The complete Material 3 theme mirroring reactui's Tailwind design system.
///
/// Usage:
/// ```dart
/// MaterialApp(theme: AppTheme.dark, darkTheme: AppTheme.dark, ...)
/// ```
class AppTheme {
  AppTheme._();

  /// The single dark theme — reactui only has dark mode.
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.bg950,

      // --- AppBar ---
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.pageTitle,
      ),

      // --- Card ---
      cardTheme: CardThemeData(
        color: AppColors.surface40,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),

      // --- Input ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inputPaddingH,
          vertical: AppSpacing.inputPaddingV,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent500),
        ),
        hintStyle: AppTypography.searchPlaceholder,
      ),

      // --- Divider ---
      dividerTheme: const DividerThemeData(
        color: AppColors.border800,
        thickness: 1,
        space: 0,
      ),

      // --- Icon ---
      iconTheme: const IconThemeData(
        color: AppColors.text400,
        size: AppSpacing.iconMd,
      ),

      // --- Tooltip ---
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.bg800,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(color: AppColors.border700),
        ),
        textStyle: AppTypography.bodySmall,
      ),

      // --- Text selection ---
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent400,
        selectionColor: AppColors.accent30,
        selectionHandleColor: AppColors.accent400,
      ),

      // --- Scrollbar ---
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border700),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
      ),
    );
  }

  static ColorScheme get _colorScheme {
    return const ColorScheme(
      brightness: Brightness.dark,
      // Primary = blue accent
      primary: AppColors.accent400,
      onPrimary: AppColors.text100,
      primaryContainer: AppColors.accent10,
      onPrimaryContainer: AppColors.accent400,
      // Secondary
      secondary: AppColors.text500,
      onSecondary: AppColors.text100,
      // Surface hierarchy
      surface: AppColors.bg900,
      onSurface: AppColors.text100,
      surfaceContainerHighest: AppColors.bg800,
      onSurfaceVariant: AppColors.text500,
      // Error
      error: AppColors.red400,
      onError: AppColors.text100,
      errorContainer: AppColors.red500_10,
      onErrorContainer: AppColors.red400,
      // Outline
      outline: AppColors.border800,
      outlineVariant: AppColors.border700,
      // Shadow / scrim
      shadow: AppColors.shadow9,
      scrim: AppColors.black60,
    );
  }
}
