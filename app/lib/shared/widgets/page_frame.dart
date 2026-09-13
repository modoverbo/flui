import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/layout/section_rhythm.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:material_ui/material_ui.dart';

/// Centres page content in the 12-column frame and adds the gutters.
///
/// One max-width policy: [FluiSpacing.contentMaxWidth] for text columns and
/// [FluiSpacing.pageMaxWidth] for the page grid. Nothing centres a 400 px
/// column inside a 1440 px window any more.
class PageFrame extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.maxWidth = FluiSpacing.pageMaxWidth,
  });

  /// A frame for a single column of reading or form content.
  const new column({required this.child, super.key})
    : maxWidth = FluiSpacing.contentMaxWidth;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: context.layout.pagePadding, child: child),
      ),
    );
  }
}

/// A full-bleed section of a long page, in the cream / green rhythm.
class PageSection extends StatelessWidget {
  const new({
    required this.child,
    required this.tone,
    super.key,
    this.maxWidth = FluiSpacing.pageMaxWidth,
  });

  final Widget child;
  final SectionTone tone;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final body = Padding(
      padding: EdgeInsets.symmetric(vertical: layout.sectionGap),
      child: PageFrame(maxWidth: maxWidth, child: child),
    );
    return switch (tone) {
      SectionTone.cream => body,
      SectionTone.green => FluiPlate.fullBleed(child: body),
    };
  }
}
