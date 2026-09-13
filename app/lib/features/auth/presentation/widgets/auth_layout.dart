import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/split_hero.dart';
import 'package:material_ui/material_ui.dart';

/// Shared layout of the auth screens.
///
/// On a wide window the form takes seven columns and a green plate takes
/// five, because a 400 px form centred in a 1440 px window is the emptiest
/// screen an app can ship.
class AuthLayout extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final type = layout.type;
    final subtitle = this.subtitle;

    final form = AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: FluiLogo(symbolSize: 32),
          ),
          SizedBox(height: layout.blockGap),
          Semantics(
            header: true,
            child: Text(
              title,
              style: type.titleL.copyWith(color: FluiColors.charcoal),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: FluiSpacing.xs),
            Text(subtitle, style: type.bodyL.copyWith(color: FluiColors.gray)),
          ],
          SizedBox(height: layout.blockGap),
          ...children,
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: layout.blockGap),
          child: PageFrame(
            maxWidth: layout.isWide
                ? FluiSpacing.pageMaxWidth
                : FluiSpacing.contentMaxWidth,
            child: layout.isWide
                ? SplitHero(content: form, support: const _AuthPlate())
                : form,
          ),
        ),
      ),
    );
  }
}

/// The promise, restated where the user is about to commit.
class _AuthPlate extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return FluiPlate(
      padding: const EdgeInsets.all(FluiSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const FluiGlyphIcon(
                FluiGlyph.replaces,
                color: FluiColors.creamMuted,
              ),
              const SizedBox(width: FluiSpacing.xs),
              FluiLabel(l10n.wordReplacesTitle, onDark: true),
            ],
          ),
          const SizedBox(height: FluiSpacing.lg),
          Text(
            '«${l10n.welcomeProofBefore}»',
            style: type.body.copyWith(
              color: FluiColors.creamMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: FluiSpacing.xs),
          Text(
            '«${l10n.welcomeProofAfter}»',
            style: type.titleM.copyWith(color: FluiColors.cream),
          ),
          const SizedBox(height: FluiSpacing.xl),
          Text(
            l10n.welcomeSupportLine,
            style: type.body.copyWith(color: FluiColors.creamMuted),
          ),
        ],
      ),
    );
  }
}
