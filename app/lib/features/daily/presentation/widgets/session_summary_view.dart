import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/presentation/widgets/mastery_meter_view.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// End of a session: what moved, how it went, what the week looks like and
/// what waits tomorrow. Exactly one celebration, and only for a milestone —
/// the first word that becomes yours.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FluiSpacing.lg),
        const Align(child: FluiSymbol(size: 72)),
        const SizedBox(height: FluiSpacing.lg),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l10n.sessionEndNewWords(newWordCount),
            textAlign: TextAlign.center,
            style: FluiTypography.h1.copyWith(color: FluiColors.charcoal),
          ),
        ),
        for (final lemma in ownedLemmas) ...[
          const SizedBox(height: FluiSpacing.lg),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: FluiColors.greenDeep,
              borderRadius: FluiRadii.xlAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.lg),
              child: Column(
                children: [
                  const FluiSymbol(tone: FluiSymbolTone.yellow),
                  const SizedBox(height: FluiSpacing.sm),
                  Text(
                    l10n.sessionEndOwned,
                    style: FluiTypography.h1.copyWith(color: FluiColors.cream),
                  ),
                  const SizedBox(height: FluiSpacing.xxs),
                  Text(
                    l10n.sessionEndOwnedBody(lemma),
                    textAlign: TextAlign.center,
                    style: FluiTypography.body.copyWith(
                      color: FluiColors.cream,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (seeding) ...[
          const SizedBox(height: FluiSpacing.lg),
          FluiNotice(
            tone: FluiNoticeTone.info,
            icon: LucideIcons.sprout,
            message: l10n.sessionSeeding,
          ),
        ],
        const SizedBox(height: FluiSpacing.lg),
        _Payoff(
          weekDays: weekDays,
          streak: streak,
          accuracyPercent: accuracyPercent,
        ),
        if (words.isNotEmpty) ...[
          const SizedBox(height: FluiSpacing.xl),
          SectionHeader(title: l10n.sessionEndWordsTitle),
          for (final word in words) ...[
            FluiCard(
              padding: const EdgeInsets.symmetric(
                horizontal: FluiSpacing.md,
                vertical: FluiSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          word.lemma,
                          style: FluiTypography.bodyEmphasis.copyWith(
                            color: FluiColors.charcoal,
                          ),
                        ),
                      ),
                      StateChip(state: word.state),
                    ],
                  ),
                  if (word.progress case final progress?) ...[
                    const SizedBox(height: FluiSpacing.xs),
                    MasteryMeterView(progress: progress, compact: true),
                  ],
                ],
              ),
            ),
            const SizedBox(height: FluiSpacing.xs),
          ],
        ],
        const SizedBox(height: FluiSpacing.lg),
        Text(
          l10n.sessionEndTomorrow(tomorrowReviews),
          textAlign: TextAlign.center,
          style: FluiTypography.bodyEmphasis.copyWith(
            color: FluiColors.greenSecondary,
          ),
        ),
        const SizedBox(height: FluiSpacing.xl),
        FluiButton.primary(label: l10n.sessionEndDone, onPressed: onDone),
      ],
    );
  }
}

/// The week dots, the streak and how this session went, in one row.
class _Payoff extends StatelessWidget {
  const new({
    required this.weekDays,
    required this.streak,
    required this.accuracyPercent,
  });

  final List<bool> weekDays;
  final int streak;
  final int? accuracyPercent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accuracy = accuracyPercent;
    return Column(
      children: [
        WeekDots(activeDays: weekDays),
        const SizedBox(height: FluiSpacing.xs),
        Text(
          l10n.sessionEndStreak(streak),
          style: FluiTypography.bodyEmphasis.copyWith(
            color: FluiColors.charcoal,
          ),
        ),
        if (accuracy != null) ...[
          const SizedBox(height: FluiSpacing.xxs),
          Text(
            '${l10n.sessionEndAccuracy(accuracy)} '
            '${l10n.sessionEndAccuracyLabel}',
            style: FluiTypography.caption.copyWith(color: FluiColors.gray),
          ),
        ],
      ],
    );
  }
}
