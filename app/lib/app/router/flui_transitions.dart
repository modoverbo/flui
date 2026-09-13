import 'package:animations/animations.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Route transitions, from the official `animations` package.
///
/// Forward steps of a flow share a horizontal axis; entering the session
/// scales in on the Z axis, because it is a different place, not the next
/// step of the same one. Reduced motion collapses both to a cut.
abstract final class FluiTransitions {
  static Page<void> sharedAxisX(Widget child, {required LocalKey key}) =>
      _page(child, key: key, type: SharedAxisTransitionType.horizontal);

  static Page<void> sharedAxisZ(Widget child, {required LocalKey key}) =>
      _page(child, key: key, type: SharedAxisTransitionType.scaled);

  static Page<void> _page(
    Widget child, {
    required LocalKey key,
    required SharedAxisTransitionType type,
  }) => CustomTransitionPage<void>(
    key: key,
    transitionDuration: FluiMotion.standard,
    reverseTransitionDuration: FluiMotion.exitOf(FluiMotion.standard),
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      if (FluiMotion.reduced(context)) return child;
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: type,
        fillColor: FluiColors.cream,
        child: child,
      );
    },
  );
}
