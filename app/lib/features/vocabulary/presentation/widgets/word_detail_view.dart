import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:material_ui/material_ui.dart';

/// Pattern P1, the hero plate: the word owns the top of the screen at
/// `wordHero`, on the green plate, and everything else is support below it.
class WordHeroPlate extends StatelessWidget {
  const new({required this.word, super.key, this.badge, this.reveal = true});

  final Word word;

  /// "Tu palabra de hoy", or the state chip in the repertoire.
  final Widget? badge;

  /// Animates the word in. Off when the word is already on screen.
  final bool reveal;

  /// Share of the viewport the plate claims.
  static const double viewportShare = 0.55;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final badge = this.badge;
    final minHeight = MediaQuery.sizeOf(context).height * viewportShare;

    final lines = <Widget>[
      if (badge != null)
        Padding(
          padding: const EdgeInsets.only(bottom: FluiSpacing.md),
          child: Align(alignment: Alignment.centerLeft, child: badge),
        ),
      Semantics(
        header: true,
        child: Text(
          word.lemma,
          style: type.wordHero.copyWith(color: FluiColors.cream),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: FluiSpacing.sm),
        child: _Pronunciation(word: word),
      ),
      Padding(
        padding: const EdgeInsets.only(top: FluiSpacing.lg),
        child: Text(
          word.explanation,
          style: type.bodyL.copyWith(color: FluiColors.cream),
        ),
      ),
    ];

    return FluiPlate.fullBleed(
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: PageFrame(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FluiSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reveal)
                    RevealLines(children: lines)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: lines,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Syllables with the stress marked, then the IPA, in tabular figures.
class _Pronunciation extends StatelessWidget {
  const new({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final ipa = word.ipaLatam ?? word.ipaEs;
    final style = context.type.phonetic.copyWith(color: FluiColors.creamMuted);
    return Semantics(
      label: context.l10n.wordSyllablesSemantics(word.syllables.join('-')),
      excludeSemantics: true,
      child: Wrap(
        spacing: FluiSpacing.sm,
        children: [
          Text.rich(
            TextSpan(
              style: style,
              children: [
                for (final (index, syllable) in word.syllables.indexed) ...[
                  if (index > 0) const TextSpan(text: ' · '),
                  TextSpan(
                    text: syllable,
                    style: index + 1 == word.stressedSyllable
                        ? style.copyWith(
                            fontWeight: FontWeight.w600,
                            color: FluiColors.cream,
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          if (ipa != null) Text(ipa, style: style),
        ],
      ),
    );
  }
}

/// The rail under the hero: how the word is actually used, one card at a
/// time, scrolled sideways instead of stacked into a wall of text.
class WordUsageRail extends StatelessWidget {
  const new({required this.word, super.key});

  final Word word;

  static const double cardWidth = 260;

  List<Widget> _cards(BuildContext context) {
    final l10n = context.l10n;
    return [
      for (final pair in word.replaces)
        _RailCard(
          label: l10n.wordReplacesTitle,
          glyph: FluiGlyph.replaces,
          child: _BeforeAfter(pair: pair),
        ),
      for (final collocation in word.collocations)
        _RailCard(
          label: l10n.wordCollocationsTitle,
          glyph: FluiGlyph.register,
          child: HighlightedText(
            text: collocation,
            forms: word.forms,
            style: context.type.bodyL.copyWith(color: FluiColors.charcoal),
          ),
        ),
      _RailCard(
        label: l10n.wordExampleTitle,
        glyph: FluiGlyph.inContext,
        child: HighlightedText(
          text: word.exampleSentence,
          forms: word.forms,
          style: context.type.bodyL.copyWith(color: FluiColors.charcoal),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards(context);
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: context.layout.pagePadding,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: FluiSpacing.sm),
        itemBuilder: (context, index) =>
            SizedBox(width: cardWidth, child: cards[index]),
      ),
    );
  }
}

class _RailCard extends StatelessWidget {
  const new({required this.label, required this.glyph, required this.child});

  final String label;
  final FluiGlyph glyph;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluiColors.surface,
        borderRadius: FluiRadii.cardAll,
        border: FluiSurfaces.borderOnCream(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FluiGlyphIcon(
                  glyph,
                  size: FluiIconSize.inline,
                  color: FluiColors.greenSecondary,
                ),
                const SizedBox(width: FluiSpacing.xs),
                Expanded(child: FluiLabel(label)),
              ],
            ),
            const SizedBox(height: FluiSpacing.sm),
            Expanded(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

class _BeforeAfter extends StatelessWidget {
  const new({required this.pair});

  final Replacement pair;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '«${pair.before}»',
          style: type.body.copyWith(
            color: FluiColors.gray,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(height: FluiSpacing.xxs),
        Text(
          '«${pair.after}»',
          style: type.bodyL.copyWith(
            color: FluiColors.greenDeep,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Descubre + Entiende, composed: the hero plate, the usage rail and the
/// notes. Used full-bleed inside a scroll view.
class WordDetailView extends StatelessWidget {
  const new({required this.word, super.key, this.badge, this.reveal = true});

  final Word word;
  final Widget? badge;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WordHeroPlate(word: word, badge: badge, reveal: reveal),
        SizedBox(height: layout.blockGap),
        WordUsageRail(word: word),
        SizedBox(height: layout.blockGap),
        PageFrame(child: WordNotes(word: word)),
      ],
    );
  }
}

/// The prose parts of a word: the tip, the warning and the confusions.
class WordNotes extends StatelessWidget {
  const new({required this.word, super.key});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;
    final usageTip = word.usageTip;
    final whenNot = word.whenNotToUse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (usageTip != null) ...[
          SectionHeader(
            title: l10n.wordUsageTipTitle,
            glyph: const FluiGlyphIcon(FluiGlyph.register),
          ),
          Text(usageTip, style: type.body.copyWith(color: FluiColors.charcoal)),
          SizedBox(height: layout.blockGap),
        ],
        if (whenNot != null) ...[
          SectionHeader(
            title: l10n.wordWhenNotTitle,
            glyph: const FluiGlyphIcon(FluiGlyph.goal),
          ),
          Text(whenNot, style: type.body.copyWith(color: FluiColors.charcoal)),
          SizedBox(height: layout.blockGap),
        ],
        if (word.confusions.isNotEmpty) ...[
          SectionHeader(
            title: l10n.wordConfusionsTitle,
            glyph: const FluiGlyphIcon(FluiGlyph.replaces),
          ),
          for (final confusion in word.confusions)
            Padding(
              padding: const EdgeInsets.only(bottom: FluiSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confusion.confusedWith,
                    style: type.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: FluiColors.charcoal,
                    ),
                  ),
                  Text(
                    confusion.difference,
                    style: type.body.copyWith(color: FluiColors.charcoal),
                  ),
                  if (confusion.memoryTrick case final trick?)
                    Text(
                      trick,
                      style: type.body.copyWith(
                        color: FluiColors.greenSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
