import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_color_rules.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/split_hero.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class WelcomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomeView(
      onStart: () => context.go(AppRoutes.intro),
      onSignIn: () => context.go(AppRoutes.login),
    );
  }
}

/// The first screen: an editorial paper canvas, the promise, and a compact
/// example of the swap next to it.
class WelcomeView extends StatelessWidget {
  const new({required this.onStart, required this.onSignIn, super.key});

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;

    return Scaffold(
      backgroundColor: FluiColors.cream,
      body: StickyCtaDock(
        dock: _Dock(onStart: onStart, onSignIn: onSignIn),
        child: SafeArea(
          // The promise sits in the middle of the page, not on top of an
          // empty half.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.only(
                bottom: StickyCtaDock.reservedHeight,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: StickyCtaDock.contentMinHeight(constraints),
                ),
                child: IntrinsicHeight(
                  child: PageFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: layout.blockGap),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: FluiLogo(symbolSize: 36),
                        ),
                        const Spacer(),
                        SplitHero(
                          content: _Tagline(
                            text: l10n.welcomeTagline,
                            highlight: l10n.welcomeTaglineHighlight,
                            support: l10n.welcomeSupportLine,
                          ),
                          support: const _SwapProof(),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const new({required this.onStart, required this.onSignIn});

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FluiButton.primary(label: l10n.welcomeStart, onPressed: onStart),
        const SizedBox(height: FluiSpacing.xs),
        FluiButton.text(label: l10n.welcomeHaveAccount, onPressed: onSignIn),
      ],
    );
  }
}

/// The promise, one line per phrase, revealed line by line.
class _Tagline extends StatelessWidget {
  const new({
    required this.text,
    required this.highlight,
    required this.support,
  });

  final String text;
  final String highlight;
  final String support;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final style = type.displayL.copyWith(color: FluiColors.charcoal);
    final split = text.endsWith(highlight)
        ? text.length - highlight.length
        : text.length;

    return RevealLines(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: text.substring(0, split)),
                if (split < text.length)
                  TextSpan(
                    // Keep the headline accent readable on the paper canvas.
                    text: text.substring(split),
                    style: const TextStyle(
                      color: FluiColorRules.onYellow,
                      backgroundColor: FluiColors.yellowElectric,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: FluiSpacing.lg),
          child: Text(
            support,
            style: type.bodyL.copyWith(color: FluiColors.gray),
          ),
        ),
      ],
    );
  }
}

/// What flui actually does, in one card: the phrase you had and the phrase
/// that fits, expressed with existing copy and a native glyph.
class _SwapProof extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.surface,
        borderRadius: FluiRadii.cardAll,
        border: Border.fromBorderSide(
          BorderSide(color: FluiColors.hairlineOnCream),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.replaces,
                  color: FluiColors.greenSecondary,
                ),
                const SizedBox(width: FluiSpacing.xs),
                FluiLabel(l10n.wordReplacesTitle),
              ],
            ),
            const SizedBox(height: FluiSpacing.sm),
            Text(
              '«${l10n.welcomeProofBefore}»',
              style: type.body.copyWith(
                color: FluiColors.gray,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: FluiSpacing.xxs),
            Text(
              '«${l10n.welcomeProofAfter}»',
              style: type.titleM.copyWith(color: FluiColors.greenDeep),
            ),
          ],
        ),
      ),
    );
  }
}
