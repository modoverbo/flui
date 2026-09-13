import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:material_ui/material_ui.dart';

/// Content that scrolls *behind* a docked call to action.
///
/// The floating pill anchored to the bottom of a half-empty screen is gone:
/// the dock is attached to the window, the page keeps its full height, and a
/// scrim plus the app's only shadow separate the two.
class StickyCtaDock extends StatelessWidget {
  const new({
    required this.child,
    required this.dock,
    super.key,
    this.onDark = false,
    this.maxWidth = FluiSpacing.contentMaxWidth,
  });

  /// The scrolling content.
  final Widget child;

  /// The docked action, usually one button plus a line of micro-copy.
  final Widget dock;
  final bool onDark;
  final double maxWidth;

  /// Bottom padding a scroll view needs so its last line clears the dock.
  static const double reservedHeight = 128;

  @override
  Widget build(BuildContext context) {
    final background = onDark ? FluiColors.greenDeep : FluiColors.cream;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Dock(
            background: background,
            onDark: onDark,
            maxWidth: maxWidth,
            child: dock,
          ),
        ),
      ],
    );
  }
}

class _Dock extends StatelessWidget {
  const new({
    required this.background,
    required this.onDark,
    required this.maxWidth,
    required this.child,
  });

  final Color background;
  final bool onDark;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A short scrim so a line of text does not end hard against the dock.
        IgnorePointer(
          child: SizedBox(
            height: FluiSpacing.lg,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [background.withValues(alpha: 0), background],
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: Border(top: FluiSurfaces.hairline(onDark: onDark)),
            boxShadow: FluiSurfaces.ctaDockShadow,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                FluiSpacing.md,
                0,
                layout.isWide ? FluiSpacing.ml : FluiSpacing.md,
              ),
              child: PageFrame(maxWidth: maxWidth, child: child),
            ),
          ),
        ),
      ],
    );
  }
}
