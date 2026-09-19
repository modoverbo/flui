import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
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

/// The first screen: a full-bleed green plate, the promise at `displayL`
/// with one yellow word, and a real example of the swap next to it.
class WelcomeView extends StatelessWidget {
  const new({required this.onStart, required this.onSignIn, super.key});

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;

    return Scaffold(
      backgroundColor: FluiColors.greenDeep,
      body: FluiPlate.fullBleed(
        child: StickyCtaDock(
          onDark: true,
          dock: _Dock(onStart: onStart, onSignIn: onSignIn),
          child: SafeArea(
            // The promise sits in the middle of the plate, not on top of an
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
                            child: FluiLogo(onDark: true, symbolSize: 36),
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
        FluiButton.accent(label: l10n.welcomeStart, onPressed: onStart),
        const SizedBox(height: FluiSpacing.xs),
        FluiButton.text(
          label: l10n.welcomeHaveAccount,
          onPressed: onSignIn,
          onDark: true,
        ),
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
    final style = type.displayL.copyWith(color: FluiColors.cream);
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
                    // One word of a marketing headline: a yellow role.
                    text: text.substring(split),
                    style: const TextStyle(color: FluiColors.yellowElectric),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: FluiSpacing.lg),
          child: Text(
            support,
            style: type.bodyL.copyWith(color: FluiColors.creamMuted),
          ),
        ),
      ],
    );
  }
}

/// What flui actually does, in one card: the word you had, the word that
/// fits. No stock photo, no illustration of a person smiling at a laptop.
class _SwapProof extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluiColors.cream,
        borderRadius: FluiRadii.plateAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 168,
                width: double.infinity,
                child: Image.asset(
                  'assets/textures/flui-voice-world.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, .45),
                ),
              ),
            ),
            const SizedBox(height: FluiSpacing.md),
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
            const SizedBox(height: FluiSpacing.md),
            Text(
              '«${l10n.welcomeProofBefore}»',
              style: type.body.copyWith(
                color: FluiColors.gray,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: FluiSpacing.xs),
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
