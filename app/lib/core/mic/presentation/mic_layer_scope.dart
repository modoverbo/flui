import 'package:flui/core/mic/mic_target.dart';
import 'package:material_ui/material_ui.dart';

/// Carries which shell branch a subtree belongs to (design §19.7): each
/// branch's navigator is wrapped in one of these by the router's
/// `navigatorContainerBuilder`, so a `MicTargetScope` further down knows
/// which [MicLayer]/branch index to register against.
///
/// Root-navigator screens (diagnosis, `/session`) are never wrapped in a
/// [MicLayerScope] — `MicTargetScope` treats a missing ancestor as
/// [MicLayer.root] (design §19.4), which is exactly the layer those screens
/// need.
class MicLayerScope extends InheritedWidget {
  const new({required this.branch, required super.child, super.key});

  /// The shell branch index this subtree lives in.
  final int branch;

  /// Resolves the [MicLayer]/branch pair for [context]: [MicLayer.branch]
  /// with the nearest ancestor's [branch] index, or [MicLayer.root] with a
  /// null index when there is no [MicLayerScope] ancestor at all.
  ///
  /// A plain (non-dependency-establishing) lookup: which branch a widget
  /// lives in does not change over that widget's lifetime, so there is
  /// nothing to rebuild for.
  static (MicLayer, int?) of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MicLayerScope>();
    return scope == null
        ? (MicLayer.root, null)
        : (MicLayer.branch, scope.branch);
  }

  @override
  bool updateShouldNotify(MicLayerScope oldWidget) =>
      branch != oldWidget.branch;
}
