import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Status badge — mirrors reactui's `text-[10px] px-1.5 py-0.5 rounded-full border`.
///
/// Variants: [AppBadge.neutral], [AppBadge.accent], [AppBadge.error], [AppBadge.success].
class AppBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    this.icon,
  });

  /// Gray neutral badge (for tags, metadata).
  factory AppBadge.neutral(String label, {IconData? icon}) {
    return AppBadge(
      label: label,
      textColor: AppColors.text400,
      backgroundColor: AppColors.bg900,
      borderColor: AppColors.border800,
      icon: icon,
    );
  }

  /// Blue accent badge (for version, selected state).
  factory AppBadge.accent(String label) {
    return AppBadge(
      label: label,
      textColor: AppColors.accent400,
      backgroundColor: AppColors.accent10,
      borderColor: AppColors.accent30,
    );
  }

  /// Red badge (for missing, error).
  factory AppBadge.error(String label) {
    return AppBadge(
      label: label,
      textColor: AppColors.red400,
      backgroundColor: AppColors.red500_10,
      borderColor: AppColors.red500_10,
    );
  }

  /// Green badge (for active, success).
  factory AppBadge.success(String label) {
    return AppBadge(
      label: label,
      textColor: AppColors.emerald500,
      backgroundColor: AppColors.emerald500.withValues(alpha: 0.1),
      borderColor: AppColors.emerald500.withValues(alpha: 0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.badgePaddingH,
        vertical: AppSpacing.badgePaddingV,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
