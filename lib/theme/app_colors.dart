import 'package:flutter/material.dart';

/// Exact color tokens from the reactui Tailwind design system.
///
/// Palette structure:
///   surface-950  → deepest bg (#030712)
///   surface-900  → sidebar / card bg (#111827)
///   surface-800  → card hover / input bg (#1f2937)
///   border-800   → default border
///   border-700   → hover border
///   accent-400   → primary interactive (#60a5fa)
///   accent-500   → focus rings (#3b82f6)
class AppColors {
  AppColors._();

  // --- Backgrounds ---
  static const Color bg950 = Color(0xFF030712);   // gray-950 — root background
  static const Color bg900 = Color(0xFF111827);   // gray-900 — sidebar / card bg
  static const Color bg800 = Color(0xFF1F2937);   // gray-800 — hover / input bg

  // --- Surfaces (layered transparency) ---
  static const Color surface40 = Color(0x0A1F2937);   // bg-gray-800/40
  static const Color surface50 = Color(0x0D1F2937);   // bg-gray-800/50
  static const Color surface80 = Color(0xCC1F2937);   // bg-gray-800/80
  static const Color surface900_50 = Color(0x80111827); // bg-gray-900/50

  // --- Borders ---
  static const Color border800 = Color(0xFF1F2937);   // gray-800
  static const Color border700 = Color(0xFF374151);   // gray-700
  static const Color border500_50 = Color(0x803B82F6); // blue-500/50 dashed

  // --- Text ---
  static const Color text100 = Color(0xFFF3F4F6);   // gray-100 — primary
  static const Color text200 = Color(0xFFE5E7EB);   // gray-200 — secondary
  static const Color text400 = Color(0xFF9CA3AF);   // gray-400 — body
  static const Color text500 = Color(0xFF6B7280);   // gray-500 — muted

  // --- Accent (blue) ---
  static const Color accent400 = Color(0xFF60A5FA);   // blue-400 — primary
  static const Color accent500 = Color(0xFF3B82F6);   // blue-500 — focus
  static const Color accent10 = Color(0x1A3B82F6);    // blue-600/10 — selected bg
  static const Color accent5 = Color(0x0D3B82F6);     // blue-500/5 — hover tint
  static const Color accent30 = Color(0x4D3B82F6);    // blue-500/30 — selection

  // --- Status ---
  static const Color emerald500 = Color(0xFF10B981);   // success
  static const Color red400 = Color(0xFFF87171);        // error
  static const Color red500 = Color(0xFFEF4444);        // error
  static const Color red500_10 = Color(0x1AEF4444);     // error badge bg

  // --- Overlay ---
  static const Color black60 = Color(0x99000000);       // modal backdrop
  static const Color shadow9 = Color(0x17000000);        // subtle shadow

  // --- Session color labels ---
  static const Color labelRed    = Color(0xFFF87171);
  static const Color labelOrange = Color(0xFFFB923C);
  static const Color labelYellow = Color(0xFFFBBF24);
  static const Color labelGreen  = Color(0xFF10B981);
  static const Color labelTeal   = Color(0xFF2DD4BF);
  static const Color labelBlue   = Color(0xFF60A5FA);
  static const Color labelPurple = Color(0xFFA78BFA);
  static const Color labelPink   = Color(0xFFF472B6);

  static const Map<String, Color> sessionColorLabels = {
    'red':    labelRed,
    'orange': labelOrange,
    'yellow': labelYellow,
    'green':  labelGreen,
    'teal':   labelTeal,
    'blue':   labelBlue,
    'purple': labelPurple,
    'pink':   labelPink,
  };
}
