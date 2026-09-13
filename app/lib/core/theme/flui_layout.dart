import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:material_ui/material_ui.dart';

enum FluiFormFactor { compact, wide }

/// The single place a screen asks "how wide am I?".
///
/// Screens read `context.layout` and take the type scale, gaps and gutters
/// from it. No screen calls `MediaQuery` for sizing: that is how a type scale
/// stops being a scale.
@immutable
final class FluiLayout {
  const new(this.formFactor);

  factory forWidth(double width) => FluiLayout(
    width >= FluiBreakpoints.wide
        ? FluiFormFactor.wide
        : FluiFormFactor.compact,
  );

  /// Resolves from the nearest [MediaQuery]. Depends on width only, so a
  /// keyboard or a rotation does not rebuild every screen.
  factory of(BuildContext context) =>
      FluiLayout.forWidth(MediaQuery.sizeOf(context).width);

  final FluiFormFactor formFactor;

  bool get isWide => formFactor == FluiFormFactor.wide;
  bool get isCompact => formFactor == FluiFormFactor.compact;

  FluiTypeScale get type => isWide ? FluiTypeScale.wide : FluiTypeScale.compact;

  double get blockGap =>
      isWide ? FluiSpacing.blockGapWide : FluiSpacing.blockGapCompact;

  double get sectionGap =>
      isWide ? FluiSpacing.sectionGapWide : FluiSpacing.sectionGapCompact;

  double get gutter =>
      isWide ? FluiSpacing.gutterWide : FluiSpacing.gutterCompact;

  /// Padding of a full page frame.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: gutter);

  /// The 12-column grid of the web layouts: 7 columns of content next to 5
  /// columns of support, inside [FluiSpacing.pageMaxWidth].
  static const int columns = 12;
  static const int heroContentColumns = 7;
  static const int heroSupportColumns = 5;

  @override
  bool operator ==(Object other) =>
      other is FluiLayout && other.formFactor == formFactor;

  @override
  int get hashCode => formFactor.hashCode;
}

extension FluiLayoutContext on BuildContext {
  /// Gaps, gutters and the resolved type scale for this viewport.
  FluiLayout get layout => FluiLayout.of(this);

  /// The resolved type scale, the shorthand screens use most.
  FluiTypeScale get type => FluiLayout.of(this).type;
}
