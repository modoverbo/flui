import 'dart:math' as math;

import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:material_ui/material_ui.dart';

/// The phone-width shell chrome (design §19.7, D29): a floating surface
/// (radius 28, margins 14/12, [FluiColors.surface]) with a 72 dp center gap
/// and a raised 64 dp circular [MicButton] instead of a 4th ordinary
/// destination.
///
/// [items] holds exactly the 4 destinations (HOY, ENTRENAR, PALABRAS,
/// PROGRESO); the mic sits between index 1 and index 2 and is never one of
/// [selectedIndex]'s destinations — tapping it never calls
/// [onDestinationSelected].
class FluiBottomBar extends StatelessWidget {
  const new({
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.progressIndex,
    this.micController,
    super.key,
  });

  final List<(FluiGlyph, String)> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int progressIndex;

  /// Null only for the brief instant around sign-out/sign-in (design
  /// §19.5's controller is session-scoped) — the mic slot stays empty
  /// rather than crashing.
  final MicController? micController;

  static const double _micDiameter = 64;
  static const double _micRaise = 20;
  static const double _micGap = 72;

  @override
  Widget build(BuildContext context) {
    final controller = micController;
    // The pill and the raised mic circle must move together against the
    // device's own bottom inset (a 3-button nav bar, a gesture pill, ...),
    // or they drift apart and the mic sinks behind the system bar. Compute
    // it once and apply it to both instead of letting a `SafeArea` push
    // only the pill while the mic's `Positioned.bottom` stays fixed.
    final safePadding = MediaQuery.paddingOf(context);
    final bottomInset = safePadding.bottom;
    final barBottomMargin = 12 + bottomInset;
    return SizedBox(
      height: 64 + _micRaise + _micDiameter / 2 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              math.max(14, safePadding.left),
              0,
              math.max(14, safePadding.right),
              barBottomMargin,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 64,
                decoration: const BoxDecoration(color: FluiColors.surface),
                child: Row(
                  children: [
                    for (final index in [0, 1])
                      Expanded(
                        child: _Destination(index: index, bar: this),
                      ),
                    const SizedBox(width: _micGap),
                    for (final index in [2, 3])
                      Expanded(
                        child: _Destination(index: index, bar: this),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: barBottomMargin + 64 - _micRaise - _micDiameter / 2,
            child: controller == null
                ? const SizedBox.square(dimension: _micDiameter)
                : MicButton(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const new({required this.index, required this.bar});

  final int index;
  final FluiBottomBar bar;

  @override
  Widget build(BuildContext context) {
    final (glyph, label) = bar.items[index];
    final selected = index == bar.selectedIndex;
    final isProgress = index == bar.progressIndex;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      hint: isProgress ? label : null,
      child: InkWell(
        onTap: () => bar.onDestinationSelected(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FluiGlyphIcon(
                glyph,
                size: FluiIconSize.tab,
                color: selected ? FluiColors.greenDeep : FluiColors.gray,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? FluiColors.ink : FluiColors.gray,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
