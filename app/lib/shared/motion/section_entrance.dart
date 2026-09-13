import 'package:flui/core/theme/flui_motion.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

/// A section arriving on a long page: a 200 ms fade and a 12 px rise, each
/// one 60 ms behind the last.
///
/// Built on `flutter_animate`, which is stable but effectively dormant
/// upstream (4.5.2, November 2024); it is used for this one declarative
/// effect, never for the product's own motion, so replacing it later is a
/// one-file change.
class SectionEntrance extends StatelessWidget {
  const new({required this.child, super.key, this.index = 0});

  final Widget child;

  /// Position in the page, for the stagger.
  final int index;

  @override
  Widget build(BuildContext context) {
    if (FluiMotion.reduced(context)) return child;
    return Animate(
      effects: [
        FadeEffect(
          duration: FluiMotion.sectionEntrance,
          delay: FluiMotion.sectionStagger * index,
          curve: FluiMotion.enter,
        ),
        MoveEffect(
          begin: const Offset(0, FluiMotion.sectionRise),
          end: Offset.zero,
          duration: FluiMotion.sectionEntrance,
          delay: FluiMotion.sectionStagger * index,
          curve: FluiMotion.enter,
        ),
      ],
      child: child,
    );
  }
}
