import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Styled card with border + hover effect — mirrors reactui card pattern.
///
/// Pattern: `bg-gray-800/40 border border-gray-800 rounded-xl p-4
///           hover:bg-gray-800/80 hover:border-gray-700`
class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color borderColor;
  final Color? hoverBorderColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 4,
    ),
    this.borderRadius = AppSpacing.cardRadius,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.borderColor = AppColors.border800,
    this.hoverBorderColor,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  Color get _bgColor {
    if (widget.backgroundColor == null) {
      return widget.onTap != null && _isHovered
          ? AppColors.surface80
          : AppColors.surface40;
    }
    return _isHovered && widget.hoverBackgroundColor != null
        ? widget.hoverBackgroundColor!
        : widget.backgroundColor!;
  }

  Color get _borderColor {
    if (_isHovered && widget.hoverBorderColor != null) {
      return widget.hoverBorderColor!;
    }
    return widget.borderColor;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppSpacing.normalTransition,
          curve: Curves.easeOut,
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: _borderColor),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
