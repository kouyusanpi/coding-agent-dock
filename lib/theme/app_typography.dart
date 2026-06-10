import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography system mirroring reactui's Tailwind text scale.
///
/// Scale: text-[10px] → text-xs → text-sm → text-base → text-lg → text-xl → text-2xl
/// All sizes follow a 1.25 modular scale from 10px base.
class AppTypography {
  AppTypography._();

  // --- Display ---
  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.text100,
  );

  // --- Headers ---
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.text500,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: AppColors.text200,
  );

  // --- Body ---
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: AppColors.text400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.text500,
  );

  // --- Labels ---
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.text400,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.text500,
  );

  static const TextStyle badgeAccent = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.accent400,
  );

  static const TextStyle badgeError = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.red400,
  );

  // --- Code / Mono ---
  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    color: AppColors.text400,
  );

  static const TextStyle monoSmall = TextStyle(
    fontSize: 11,
    fontFamily: 'monospace',
    color: AppColors.text500,
  );

  // --- Meta ---
  static const TextStyle meta = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.text500,
  );

  /// Sidebar item — 14px, weight varies by state.
  static TextStyle sidebarItem({bool selected = false}) => TextStyle(
    fontSize: 14,
    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
    letterSpacing: -0.1,
    color: selected ? AppColors.accent400 : AppColors.text400,
  );

  /// Search placeholder.
  static const TextStyle searchPlaceholder = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.text400,
  );
}
