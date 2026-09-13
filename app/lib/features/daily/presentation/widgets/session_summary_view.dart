import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/presentation/widgets/mastery_meter_view.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:material_ui/material_ui.dart';

/// End of a session: what moved, how it went, what the week looks like and
/// what waits tomorrow. Exactly one celebration, and only for a milestone —
/// the first word that becomes yours, or a streak of 3, 7, 14 or 30 days.
class SessionSummaryView extends StatelessWidget {
  const new({
    required this.newWordCount,
    required this.words,
    required this.ownedLemmas,
    required this.seeding,
    required this.weekDays,
    required this.streak,
    required this.tomorrowReviews,
    required this.onDone,
    super.key,
    this.accuracyPercent,
  });

  final int newWordCount;

  /// Words this session moved, with the state they are in now and how far
  /// along their five-rung meter they are.
  final List<({String lemma, WordStateKind state, WordProgress? progress})>
  words;
  final List<String> ownedLemmas;
  final bool seeding;

  /// Monday to Sunday of the current week: `true` when active.
  final List<bool> weekDays;
  final int streak;
  final int tomorrowReviews;

  /// First-try share of this session, `null` when nothing was answered.
  final int? accuracyPercent;
  final VoidCallback onDone;

  bool get celebrates =>
      ownedLemmas.isNotEmpty || FluiMotion.isMilestone(streak);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: layout.blockGap),
        RevealLines(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                l10n.sessionEndNewWords(newWordCount),
                style: type.displayL.copyWith(color: FluiColors.charcoal),
              ),
            ),
          ],
        ),
        SizedBox(height: layout.blockGap),
        _Payoff(
          weekDays: weekDays,
          streak: streak,
          accuracyPercent: accuracyPercent,
          celebrates: celebrates,
        ),
        for (final lemma in ownedLemmas) ...[
          SizedBox(height: layout.blockGap),
          FluiPlate(
            padding: const EdgeInsets.all(FluiSpacing.ml),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.achievement,
                  color: FluiColors.yellowElectric,
                ),
                const SizedBox(height: FluiSpacing.sm),
                Text(
                  l10n.sessionEndOwned,
                  style: type.titleL.copyWith(color: FluiColors.cream),
                ),
                const SizedBox(height: FluiSpacing.xxs),
                Text(
                  l10n.sessionEndOwnedBody(lemma),
                  style: type.bodyL.copyWith(color: FluiColors.creamMuted),
                ),
              ],
            ),
          ),
        ],
        if (seeding) ...[
          SizedBox(height: layout.blockGap),
          FluiNotice(
            tone: FluiNoticeTone.info,
            glyph: const FluiGlyphIcon(FluiGlyph.onda),
            message: l10n.sessionSeeding,
          ),
        ],
        if (words.isNotEmpty) ...[
          SizedBox(height: layout.sectionGap),
          SectionHeader(
            title: l10n.sessionEndWordsTitle,
            glyph: const FluiGlyphIcon(FluiGlyph.wordOfTheDay),
          ),
          for (final word in words) ...[
            FluiCard(
              padding: const EdgeInsets.all(FluiSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          word.lemma,
                          style: type.titleM.copyWith(
                            color: FluiColors.charcoal,
                          ),
                        ),
                      ),
                      StateChip(state: word.state),
                    ],
                  ),
                  if (word.progress case final progress?) ...[
                    const SizedBox(height: FluiSpacing.sm),
                    MasteryMeterView(progress: progress, compact: true),
                  ],
                ],
              ),
            ),
            const SizedBox(height: FluiSpacing.xs),
          ],
        ],
        SizedBox(height: layout.blockGap),
        Text(
          l10n.sessionEndTomorrow(tomorrowReviews),
          style: type.bodyL.copyWith(
            color: FluiColors.greenSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: layout.blockGap),
        FluiButton.primary(label: l10n.sessionEndDone, onPressed: onDone),
        SizedBox(height: layout.blockGap),
      ],
    );
  }
}

/// The week, the streak and how this session went, on one plate.
class _Payoff extends StatelessWidget {
  const new({
    required this.weekDays,
    required this.streak,
    required this.accuracyPercent,
    required this.celebrates,
  });

  final List<bool> weekDays;
  final int streak;
  final int? accuracyPercent;
  final bool celebrates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final accuracy = accuracyPercent;
    return FluiPlate(
      padding: const EdgeInsets.all(FluiSpacing.ml),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FluiGlyphIcon(
                FluiGlyph.streak,
                color: FluiColors.creamMuted,
              ),
              const SizedBox(width: FluiSpacing.xs),
              Expanded(
                child: Text(
                  l10n.sessionEndStreak(streak),
                  style: type.titleM.copyWith(
                    color: celebrates
                        ? FluiColors.yellowElectric
                        : FluiColors.cream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FluiSpacing.md),
          WeekDots(activeDays: weekDays),
          if (accuracy != null) ...[
            const SizedBox(height: FluiSpacing.md),
            FluiLabel(
              '${l10n.sessionEndAccuracy(accuracy)} '
              '${l10n.sessionEndAccuracyLabel}',
              onDark: true,
            ),
          ],
        ],
      ),
    );
  }
}
