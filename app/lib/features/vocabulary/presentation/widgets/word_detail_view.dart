import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Descubre + Entiende: everything about a word, read top to bottom.
class WordDetailView extends StatelessWidget {
  const new({required this.word, super.key, this.badge});

  final Word word;

  /// Shown above the word, for example "Tu palabra de hoy" or a state chip.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badge = this.badge;
    final forms = word.forms;
    final usageTip = word.usageTip;
    final whenNot = word.whenNotToUse;
    final ipa = word.ipaLatam ?? word.ipaEs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (badge != null) ...[
          Align(alignment: Alignment.centerLeft, child: badge),
          const SizedBox(height: FluiSpacing.md),
        ],
        Semantics(
          header: true,
          child: Text(
            word.lemma,
            style: FluiTypography.featuredWord.copyWith(
              color: FluiColors.charcoal,
            ),
          ),
        ),
        const SizedBox(height: FluiSpacing.xxs),
        _Pronunciation(word: word, ipa: ipa),
        const SizedBox(height: FluiSpacing.lg),
        Text(
          word.explanation,
          style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
        ),
        const SizedBox(height: FluiSpacing.lg),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: FluiColors.greenTint,
            borderRadius: FluiRadii.lgAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(FluiSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.quote,
                  size: 20,
                  color: FluiColors.greenDeep,
                ),
                const SizedBox(width: FluiSpacing.sm),
                Expanded(
                  child: HighlightedText(
                    text: word.exampleSentence,
                    forms: forms,
                    style: FluiTypography.body.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (word.replaces.isNotEmpty) ...[
          const SizedBox(height: FluiSpacing.lg),
          _SectionTitle(title: l10n.wordReplacesTitle),
          for (final pair in word.replaces) _ReplacementRow(pair: pair),
        ],
        if (usageTip != null) ...[
          const SizedBox(height: FluiSpacing.lg),
          _SectionTitle(title: l10n.wordUsageTipTitle),
          _Paragraph(text: usageTip),
        ],
        if (whenNot != null) ...[
          const SizedBox(height: FluiSpacing.lg),
          _SectionTitle(title: l10n.wordWhenNotTitle),
          _Paragraph(text: whenNot),
        ],
        if (word.confusions.isNotEmpty) ...[
          const SizedBox(height: FluiSpacing.lg),
          _SectionTitle(title: l10n.wordConfusionsTitle),
          for (final confusion in word.confusions)
            _ConfusionRow(confusion: confusion),
        ],
      ],
    );
  }
}

class _Pronunciation extends StatelessWidget {
  const new({required this.word, required this.ipa});

  final Word word;
  final String? ipa;

  @override
  Widget build(BuildContext context) {
    final ipa = this.ipa;
    final style = FluiTypography.body.copyWith(color: FluiColors.gray);
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
                            color: FluiColors.charcoal,
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

class _SectionTitle extends StatelessWidget {
  const new({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: FluiTypography.h3.copyWith(color: FluiColors.charcoal),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
  );
}

class _ReplacementRow extends StatelessWidget {
  const new({required this.pair});

  final Replacement pair;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.xs),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: FluiSpacing.xs,
        runSpacing: FluiSpacing.xxs,
        children: [
          _Chip(text: pair.before, muted: true),
          const Icon(LucideIcons.arrow_right, size: 16, color: FluiColors.gray),
          _Chip(text: pair.after, muted: false),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({required this.text, required this.muted});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted ? FluiColors.surface : FluiColors.greenTint,
        borderRadius: FluiRadii.mdAll,
        border: Border.all(
          color: muted ? FluiColors.outline : FluiColors.greenTint,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FluiSpacing.sm,
          vertical: FluiSpacing.xxs,
        ),
        child: Text(
          text,
          style: FluiTypography.body.copyWith(
            fontSize: 14,
            color: muted ? FluiColors.gray : FluiColors.greenDeep,
            fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConfusionRow extends StatelessWidget {
  const new({required this.confusion});

  final WordConfusion confusion;

  @override
  Widget build(BuildContext context) {
    final trick = confusion.memoryTrick;
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            confusion.confusedWith,
            style: FluiTypography.bodyEmphasis.copyWith(
              color: FluiColors.charcoal,
            ),
          ),
          _Paragraph(text: confusion.difference),
          if (trick != null)
            Text(
              trick,
              style: FluiTypography.body.copyWith(
                color: FluiColors.greenDeep,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
