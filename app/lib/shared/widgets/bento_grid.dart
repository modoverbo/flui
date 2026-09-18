import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/shared/layout/bento_layout.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:material_ui/material_ui.dart';

/// One tile of the bento.
@immutable
final class BentoTile {
  const new({
    required this.span,
    required this.child,
    this.tone = BentoTone.cream,
    this.onTap,
    this.semanticLabel,
  });

  final BentoSpan span;
  final Widget child;
  final BentoTone tone;
  final VoidCallback? onTap;
  final String? semanticLabel;
}

/// The surface of a tile. The dark tile is the anchor of the grid; there is
/// at most one per bento.
enum BentoTone {
  cream,
  green,
  yellow,
  ink,
  blue,
  lime,
  coral,
  aqua,
  pink,
  lavender,
}

Color bentoToneColor(BentoTone tone) => switch (tone) {
  BentoTone.cream => FluiColors.surface,
  BentoTone.green => FluiColors.greenDeep,
  BentoTone.yellow => FluiColors.yellowElectric,
  BentoTone.ink => FluiColors.ink,
  BentoTone.blue => FluiColors.electricBlue,
  BentoTone.lime => FluiColors.acidLime,
  BentoTone.coral => FluiColors.coral,
  BentoTone.aqua => FluiColors.aqua,
  BentoTone.pink => FluiColors.softPink,
  BentoTone.lavender => FluiColors.lavender,
};

/// An asymmetric bento: a 2-column grid with one dark anchor, singles and a
/// full-width tile, replacing the row of identical KPI boxes.
///
/// Cells have a fixed aspect ratio, so the composition reaches the fold on a
/// short window and never stretches into slabs on a tall one.
class BentoGrid extends StatelessWidget {
  const new({required this.tiles, super.key, this.cellAspectRatio = 1.15});

  /// Width divided by height of one cell.
  final double cellAspectRatio;
  final List<BentoTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final spacing = context.layout.isWide ? FluiSpacing.md : FluiSpacing.sm;
    final placements = packBento([for (final tile in tiles) tile.span]);
    final rows = bentoRowCount(placements);

    // A cell grows faster than the text inside it: padding and glyphs do not
    // scale, so at 130 % type the grid gets taller instead of clipping.
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final cellGrowth = 1 + (textScale - 1) * 1.6;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - spacing) / 2;
        final cellHeight = cellWidth * cellGrowth / cellAspectRatio;
        final height = rows * cellHeight + (rows - 1) * spacing;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (final (index, placement) in placements.indexed)
                Positioned(
                  left: placement.column * (cellWidth + spacing),
                  top: placement.row * (cellHeight + spacing),
                  width:
                      placement.span.columns * cellWidth +
                      (placement.span.columns - 1) * spacing,
                  height:
                      placement.span.rows * cellHeight +
                      (placement.span.rows - 1) * spacing,
                  child: _Tile(tile: tiles[index]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const new({required this.tile});

  final BentoTile tile;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.all(
      tile.span == BentoSpan.large ? FluiSpacing.lg : FluiSpacing.md,
    );
    final content = Padding(padding: padding, child: tile.child);

    final surface = switch (tile.tone) {
      BentoTone.green => FluiPlate(
        borderRadius: FluiRadii.cardAll,
        child: content,
      ),
      BentoTone.cream => DecoratedBox(
        decoration: BoxDecoration(
          color: FluiColors.surface,
          borderRadius: FluiRadii.cardAll,
          border: FluiSurfaces.borderOnCream(),
        ),
        child: content,
      ),
      BentoTone.yellow => DecoratedBox(
        decoration: const BoxDecoration(
          color: FluiColors.yellowElectric,
          borderRadius: FluiRadii.cardAll,
        ),
        child: content,
      ),
      BentoTone.ink ||
      BentoTone.blue ||
      BentoTone.lime ||
      BentoTone.coral ||
      BentoTone.aqua ||
      BentoTone.pink ||
      BentoTone.lavender => DecoratedBox(
        decoration: BoxDecoration(
          color: bentoToneColor(tile.tone),
          borderRadius: FluiRadii.cardAll,
          border: Border.all(color: FluiColors.ink, width: 1.5),
        ),
        child: content,
      ),
    };

    final onTap = tile.onTap;
    final tapped = onTap == null
        ? surface
        : Stack(
            fit: StackFit.expand,
            children: [
              surface,
              Material(
                color: Colors.transparent,
                borderRadius: FluiRadii.cardAll,
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: onTap),
              ),
            ],
          );

    final label = tile.semanticLabel;
    if (label == null) return tapped;
    return Semantics(
      label: label,
      button: onTap != null,
      excludeSemantics: true,
      child: tapped,
    );
  }
}
