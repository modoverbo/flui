import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/widgets/mastery_meter_view.dart';
import 'package:flui/features/vocabulary/presentation/widgets/word_detail_view.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// `/words/:wordId`: a word of the repertoire, read-only.
class WordDetailPage extends ConsumerWidget {
  const new({required this.wordId, super.key});

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(wordEntryProvider(wordId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.wordBackToWords,
          icon: const Icon(LucideIcons.arrow_left),
          onPressed: () => context.go(AppRoutes.words),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: FluiSpacing.lg),
          child: ContentColumn(
            child: switch (entry) {
              AsyncValue(hasValue: true, :final WordEntry value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WordDetailView(
                    word: value.word,
                    badge: StateChip(state: value.progress.state.chipKind),
                  ),
                  if (value.progress.nextDueOn case final due?
                      when !value.isDue) ...[
                    const SizedBox(height: FluiSpacing.lg),
                    Text(
                      l10n.wordNextReview(formatLongDate(due.toDateTime())),
                      style: FluiTypography.body.copyWith(
                        color: FluiColors.gray,
                      ),
                    ),
                  ],
                  if (value.isDue) ...[
                    const SizedBox(height: FluiSpacing.xl),
                    FluiButton.primary(
                      label: l10n.wordPracticeNow,
                      onPressed: () => context.go(AppRoutes.sessionReview),
                    ),
                  ],
                  const SizedBox(height: FluiSpacing.xl),
                  MasteryMeterView(progress: value.progress),
                  if (value.word.readings.isNotEmpty) ...[
                    const SizedBox(height: FluiSpacing.xl),
                    SectionHeader(title: l10n.todayContextTitle),
                    ReadingsCarousel(
                      readings: rotate(
                        value.word.readings,
                        daysSinceEpoch(ref.watch(clockProvider).localToday()),
                      ),
                      forms: value.word.forms,
                    ),
                  ],
                ],
              ),
              AsyncValue(hasValue: true) || AsyncError() => EmptyState(
                title: l10n.wordNotFound,
                message: l10n.wordsEmptyBody,
                actionLabel: l10n.wordBackToWords,
                onAction: () => context.go(AppRoutes.words),
              ),
              _ => Center(
                child: LoadingWave(semanticLabel: l10n.commonLoading),
              ),
            },
          ),
        ),
      ),
    );
  }
}
