/// Spacing and layout constants from reactui's design system.
///
/// Key measurements (in logical pixels):
///   sidebar  → 256 (w-64)
///   header   → 56  (h-14)
///   content  → 896 (max-w-4xl) centered
///   card pad → 16-24 (p-4 to p-6)
///   gap      → 12  (gap-3)
///   radius   → 12  (rounded-xl)
class AppSpacing {
  AppSpacing._();

  // --- Layout ---
  static const double sidebarWidth = 256;   // w-64
  static const double headerHeight = 56;    // h-14
  static const double contentMaxWidth = 896; // max-w-4xl
  static const double contentPadding = 24;   // p-6

  // --- Card ---
  static const double cardPadding = 16;     // p-4
  static const double cardGap = 12;          // gap-3
  static const double cardRadius = 12;       // rounded-xl
  static const double cardBorderWidth = 1;

  // --- Item spacing ---
  static const double itemGap = 4;           // space-y-1
  static const double sectionGap = 8;        // mb-2
  static const double contentGap = 32;       // mt-8 / mb-8
  static const double inlineGap = 16;        // space-x-4

  // --- Input ---
  static const double inputRadius = 8;       // rounded-lg
  static const double inputPaddingH = 12;    // px-3
  static const double inputPaddingV = 8;     // py-2

  // --- Badge ---
  static const double badgeRadius = 12;      // rounded-full
  static const double badgePaddingH = 6;     // px-1.5
  static const double badgePaddingV = 2;     // py-0.5

  // --- Modal ---
  static const double modalRadius = 16;      // rounded-2xl
  static const double modalPadding = 24;     // p-6

  // --- Icon ---
  static const double iconSm = 14;           // w-3.5
  static const double iconMd = 16;           // w-4
  static const double iconLg = 20;           // w-5
  static const double iconXl = 32;           // w-8

  // --- Sidebar ---
  static const double sidebarItemRadius = 6;  // rounded-md
  static const double sidebarItemPaddingH = 12; // px-3
  static const double sidebarItemPaddingV = 8;  // py-2

  // --- Animation ---
  static const Duration fastTransition = Duration(milliseconds: 150);
  static const Duration normalTransition = Duration(milliseconds: 200);
  static const Duration scanDuration = Duration(milliseconds: 1200);
}
