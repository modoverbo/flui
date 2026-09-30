import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/presentation/mic_target_scope.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/controllers/word_speak_target.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/features/vocabulary/presentation/widgets/mastery_meter_view.dart';
import 'package:flui/features/vocabulary/presentation/widgets/word_detail_view.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// The domain entity is called Theme, like Flutter's inherited widget; this
// screen needs the entity, never the widget.
import 'package:material_ui/material_ui.dart' hide Theme;

/// `/words/:wordId`: pattern P1 — the word owns the top of the screen, the
/// rail shows how it is used, and "En contexto" lives here now.
///
/// Shows the word's cloze exercise alongside the catalog info ("cloze in
/// one place", U17) and registers `WordSpeakTarget` with the shell's mic
/// via `MicTargetScope`.
class WordDetailPage extends ConsumerWidget {
  const new({required this.wordId, super.key});

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wordsById = ref.watch(wordsByIdProvider);
    final entry = ref.watch(wordEntryProvider(wordId)).asData?.value;
    final themesById = ref.watch(themesByIdProvider).value;
    final word = wordsById.asData?.value[wordId];
    final body = Scaffold(
      body: word != null
          ? _Detail(
              word: word,
              entry: entry,
              today: ref.watch(clockProvider).localToday(),
              themesById: themesById,
            )
          : wordsById.hasError
          ? SafeArea(
              child: PageFrame(
                child: Padding(
                  padding: const EdgeInsets.only(top: FluiSpacing.xl),
                  child: EmptyState(
                    title: l10n.todayLoadError,
                    message: switch (wordsById.error) {
                      final Failure failure => failureMessage(l10n, failure),
                      _ => l10n.errorUnexpected,
                    },
                    actionLabel: l10n.commonRetry,
                    onAction: () => ref.invalidate(catalogProvider),
                  ),
                ),
              ),
            )
          : wordsById.isLoading
          ? Center(child: LoadingWave(semanticLabel: l10n.commonLoading))
          : SafeArea(
              child: PageFrame(
                child: Padding(
                  padding: const EdgeInsets.only(top: FluiSpacing.xl),
                  child: EmptyState(
                    title: l10n.wordNotFound,
                    message: l10n.wordsEmptyBody,
                    actionLabel: l10n.wordBackToWords,
                    onAction: () => context.go(AppRoutes.words),
                  ),
                ),
              ),
            ),
    );
    final target = ref.watch(wordSpeakTargetProvider(wordId))
      ..onDelivered = () => context.go(AppRoutes.wordSpeak(wordId));
    return MicTargetScope(target: target, child: body);
  }
}

class _Detail extends StatelessWidget {
  const new({
    required this.word,
    required this.entry,
    required this.today,
    required this.themesById,
  });

  final Word word;
  final WordEntry? entry;
  final LocalDate today;

  /// The taxonomy, to resolve this word's own theme colour. `null` while
  /// still loading — the hero simply keeps the brand plate until it
  /// resolves.
  final Map<String, Theme>? themesById;

  /// This word's own resolved theme colour (id -> slug ->
  /// [FluiThemeColors.resolve]).
  ///
  /// Never resolves the raw theme id directly: `FluiThemeColors.resolve`
  /// only recognises slugs, and a raw id would silently fall back to the
  /// neutral colour (the bug fixed in commit de5bd47 for the session card;
  /// replicated as a fix here, not repeated as a bug).
  FluiThemeColor? get _themeColor {
    final slug = themesById?[word.themeIds.firstOrNull]?.slug;
    return slug == null ? null : FluiThemeColors.resolve(slug);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final progress = entry?.progress;
    final due = progress?.nextDueOn;

    final body = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: WordHeroPlate(
            key: const Key('wordHero'),
            word: word,
            badge: progress == null
                ? null
                : StateChip(state: progress.state.chipKind),
            themeColor: _themeColor,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: layout.blockGap)),
        SliverToBoxAdapter(
          child: PageFrame(
            child: SectionHeader(
              title: l10n.wordUsesTitle,
              glyph: const FluiGlyphIcon(FluiGlyph.replaces),
            ),
          ),
        ),
        SliverToBoxAdapter(child: WordUsageRail(word: word)),
        SliverToBoxAdapter(child: SizedBox(height: layout.sectionGap)),
        SliverToBoxAdapter(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (word.exercises.isNotEmpty) ...[
                  _PracticeCard(
                    exercise: _lowestPosition(word.exercises),
                    forms: word.forms,
                  ),
                  SizedBox(height: layout.sectionGap),
                ],
                WordNotes(word: word),
                if (word.readings.isNotEmpty) ...[
                  SectionHeader(
                    title: l10n.todayContextTitle,
                    glyph: const FluiGlyphIcon(FluiGlyph.inContext),
                  ),
                  ReadingsCarousel(
                    readings: rotate(word.readings, daysSinceEpoch(today)),
                    forms: word.forms,
                  ),
                  SizedBox(height: layout.sectionGap),
                ],
                if (progress != null) ...[
                  SectionHeader(
                    title: l10n.masteryTitle,
                    glyph: const FluiGlyphIcon(FluiGlyph.goal),
                  ),
                  MasteryMeterView(progress: progress),
                ],
                if (due != null && entry?.isDue == false) ...[
                  const SizedBox(height: FluiSpacing.md),
                  Text(
                    l10n.wordNextReview(formatLongDate(due.toDateTime())),
                    style: layout.type.body.copyWith(color: FluiColors.gray),
                  ),
                ],
                SizedBox(height: layout.sectionGap),
              ],
            ),
          ),
        ),
      ],
    );

    final scroll = Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: IconButton(
              tooltip: l10n.wordBackToWords,
              onPressed: () => context.go(AppRoutes.words),
              icon: const Icon(LucideIcons.arrow_left, color: FluiColors.cream),
            ),
          ),
        ),
      ],
    );

    if (entry?.isDue != true) return scroll;
    return StickyCtaDock(
      dock: FluiButton.primary(
        label: l10n.wordPracticeNow,
        onPressed: () => context.go(AppRoutes.sessionReview),
      ),
      child: scroll,
    );
  }

  static ClozeExercise _lowestPosition(List<ClozeExercise> exercises) =>
      exercises.reduce((a, b) => a.position <= b.position ? a : b);
}

/// "Cloze in one place" (U17, detail-3's own PALABRAS acceptance text):
/// the word's own fill-in-the-blank exercise, filled with its correct
/// answer, shown alongside the catalog info instead of only reachable
/// through `/session`. The spoken action itself is the mic
/// ("Úsala en voz alta", `WordSpeakTarget`) — this card is informational,
/// never a second typed exercise / record button.
class _PracticeCard extends StatelessWidget {
  const new({required this.exercise, required this.forms});

  final ClozeExercise exercise;
  final WordForms forms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final parts = exercise.sentenceParts;
    final filled =
        '${parts.before}${exercise.correctOption.text}${parts.after}';
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l10n.wordPracticeCardTitle,
            glyph: const FluiGlyphIcon(FluiGlyph.goal),
          ),
          FluiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightedText(
                  text: filled,
                  forms: forms,
                  style: layout.type.bodyL.copyWith(color: FluiColors.charcoal),
                ),
                const SizedBox(height: FluiSpacing.sm),
                Text(
                  exercise.explanation,
                  style: layout.type.body.copyWith(color: FluiColors.gray),
                ),
              ],
            ),
          ),
          const SizedBox(height: FluiSpacing.sm),
          Text(
            l10n.wordSpeakHint,
            style: layout.type.body.copyWith(color: FluiColors.greenSecondary),
          ),
        ],
      ),
    );
  }
}
