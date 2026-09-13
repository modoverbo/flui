import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/widgets/mastery_meter_view.dart';
import 'package:flui/features/vocabulary/presentation/widgets/word_detail_view.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/words/:wordId`: pattern P1 — the word owns the top of the screen, the
/// rail shows how it is used, and "En contexto" lives here now.
class WordDetailPage extends ConsumerWidget {
  const new({required this.wordId, super.key});

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(wordEntryProvider(wordId));
    return Scaffold(
      body: switch (entry) {
        AsyncValue(hasValue: true, :final WordEntry value) => _Detail(
          entry: value,
          today: ref.watch(clockProvider).localToday(),
        ),
        AsyncValue(hasValue: true) || AsyncError() => SafeArea(
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
        _ => Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const new({required this.entry, required this.today});

  final WordEntry entry;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final word = entry.word;
    final due = entry.progress.nextDueOn;

    final body = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: WordHeroPlate(
            word: word,
            badge: StateChip(state: entry.progress.state.chipKind),
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
                SectionHeader(
                  title: l10n.masteryTitle,
                  glyph: const FluiGlyphIcon(FluiGlyph.goal),
                ),
                MasteryMeterView(progress: entry.progress),
                if (due != null && !entry.isDue) ...[
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

    if (!entry.isDue) return scroll;
    return StickyCtaDock(
      dock: FluiButton.primary(
        label: l10n.wordPracticeNow,
        onPressed: () => context.go(AppRoutes.sessionReview),
      ),
      child: scroll,
    );
  }
}
