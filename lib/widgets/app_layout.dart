import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Responsive layout scaffold — resizable sidebar + header + content area.
///
/// Mirrors reactui App layout, with an elastic split: the divider between
/// the sidebar and the main area can be dragged to resize both panels.
/// The chosen width is clamped to sane bounds, capped relative to the
/// window, and persisted across launches via [SettingsService].
class AppLayout extends StatefulWidget {
  final Widget sidebar;
  final Widget header;
  final Widget body;
  final bool constrainContent;

  const AppLayout({
    super.key,
    required this.sidebar,
    required this.header,
    required this.body,
    this.constrainContent = true,
  });

  /// Sidebar resize bounds.
  static const double minSidebarWidth = 200;
  static const double maxSidebarWidth = 480;

  /// Key for the divider drag handle (used by widget tests).
  static const Key dividerKey = Key('app_layout_divider');

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  late double _sidebarWidth;
  bool _dragging = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _sidebarWidth = _clamp(
      SettingsService.sidebarWidth ?? AppSpacing.sidebarWidth,
      double.infinity,
    );
  }

  double _clamp(double width, double available) {
    final dynamicMax = available.isFinite
        ? (available / 2).clamp(
            AppLayout.minSidebarWidth, AppLayout.maxSidebarWidth)
        : AppLayout.maxSidebarWidth;
    return width.clamp(AppLayout.minSidebarWidth, dynamicMax);
  }

  void _onDragUpdate(DragUpdateDetails details, double available) {
    setState(() {
      _sidebarWidth = _clamp(_sidebarWidth + details.delta.dx, available);
    });
  }

  void _onDragEnd() {
    setState(() => _dragging = false);
    SettingsService.setSidebarWidth(_sidebarWidth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg950,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = _clamp(_sidebarWidth, constraints.maxWidth);
          return Row(
            children: [
              // Sidebar (resizable)
              SizedBox(width: width, child: widget.sidebar),

              // Drag handle — 6px hit area straddling the divider line.
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) => setState(() => _hovering = false),
                child: GestureDetector(
                  key: AppLayout.dividerKey,
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) =>
                      setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) =>
                      _onDragUpdate(d, constraints.maxWidth),
                  onHorizontalDragEnd: (_) => _onDragEnd(),
                  onHorizontalDragCancel: _onDragEnd,
                  child: AnimatedContainer(
                    duration: AppSpacing.fastTransition,
                    width: 6,
                    color: _dragging
                        ? AppColors.accent30
                        : _hovering
                            ? AppColors.accent10
                            : Colors.transparent,
                  ),
                ),
              ),

              // Main area
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.bg900,
                        AppColors.bg950,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      SizedBox(
                        height: AppSpacing.headerHeight,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border800),
                            ),
                          ),
                          child: widget.header,
                        ),
                      ),

                      // Body
                      Expanded(
                        child: widget.constrainContent
                            ? Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: AppSpacing.contentMaxWidth,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.contentPadding,
                                    ),
                                    child: widget.body,
                                  ),
                                ),
                              )
                            : widget.body,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
