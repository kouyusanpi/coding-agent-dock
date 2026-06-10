import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Search bar with Cmd+K hint — mirrors reactui's search input.
///
/// Pattern: `bg-gray-800 border-gray-700 rounded-lg focus:ring-1 focus:ring-blue-500`
class AppSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const AppSearchBar({
    super.key,
    this.hintText = 'Search sessions, tags, or workspaces... (Cmd + K)',
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.body,
        cursorColor: AppColors.accent400,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: AppSpacing.iconMd),
          prefixIconColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return AppColors.accent500;
            }
            return AppColors.text400;
          }),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border700),
                color: AppColors.bg800,
              ),
              child: const Text(
                '⌘K',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.text500,
                ),
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(),
        ),
      ),
    );
  }
}
