import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/presentation/mic_layer_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Registers [target] with the shell's `MicTargetRegistry` for as long as
/// this widget is mounted (design §19.7): `register` in `initState`,
/// `update` in `didUpdateWidget` when [target] changes, `dispose` in
/// `dispose`.
///
/// Picks its [MicLayer]/branch from the nearest [MicLayerScope] ancestor —
/// [MicLayer.root] with no ancestor (root-navigator screens), or
/// [MicLayer.branch] at that ancestor's branch index otherwise (a shell
/// branch's own screens).
class MicTargetScope extends ConsumerStatefulWidget {
  const new({required this.target, required this.child, super.key});

  final MicTarget target;
  final Widget child;

  @override
  ConsumerState<MicTargetScope> createState() => _MicTargetScopeState();
}

class _MicTargetScopeState extends ConsumerState<MicTargetScope> {
  MicRegistration? _registration;

  @override
  void initState() {
    super.initState();
    final (layer, branch) = MicLayerScope.of(context);
    _registration = ref
        .read(micTargetRegistryProvider)
        .register(widget.target, layer: layer, branch: branch);
  }

  @override
  void didUpdateWidget(covariant MicTargetScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _registration?.update(widget.target);
    }
  }

  @override
  void dispose() {
    _registration?.dispose();
    _registration = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
