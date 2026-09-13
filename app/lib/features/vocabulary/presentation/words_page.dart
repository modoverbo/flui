import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_header.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// "Palabras": the user's repertoire, filterable by state.
class WordsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends ConsumerState<WordsPage> {
  WordState? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = ref.watch(myWordsProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(title: l10n.navWords, subtitle: l10n.wordsSubtitle),
                const SizedBox(height: FluiSpacing.lg),
                switch (words) {
                  AsyncValue(hasValue: true, :final value?)
                      when value.isEmpty =>
                    EmptyState(
                      title: l10n.wordsEmptyTitle,
                      message: l10n.wordsEmptyBody,
                    ),
                  AsyncValue(hasValue: true, :final value?) => _WordList(
                    entries: value,
                    filter: _filter,
                    onFilter: (state) => setState(() => _filter = state),
                  ),
                  AsyncError(:final error) => EmptyState(
                    title: l10n.todayLoadError,
                    message: error is Failure
                        ? failureMessage(l10n, error)
                        : l10n.errorUnexpected,
                    actionLabel: l10n.commonRetry,
                    onAction: () => retryLearningData(ref),
                  ),
                  _ => Center(
                    child: LoadingWave(semanticLabel: l10n.commonLoading),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordList extends StatelessWidget {
  const new({
    required this.entries,
    required this.filter,
    required this.onFilter,
  });

  final List<WordEntry> entries;
  final WordState? filter;
  final ValueChanged<WordState?> onFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = [
      for (final entry in entries)
        if (filter == null || entry.progress.state == filter) entry,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceChips<WordState?>(
          values: const [null, ...WordState.values],
          selected: filter,
          labelOf: (state) => switch (state) {
            null => l10n.wordsFilterAll,
            WordState.nueva => l10n.wordStateNew,
            WordState.practica => l10n.wordStatePractice,
            WordState.tuya => l10n.wordStateOwned,
          },
          onSelected: onFilter,
        ),
        const SizedBox(height: FluiSpacing.md),
        if (visible.isEmpty)
          Text(
            l10n.wordsFilterEmpty,
            style: FluiTypography.body.copyWith(color: FluiColors.gray),
          ),
        for (final entry in visible) ...[
          FluiCard(
            onTap: () => context.go(AppRoutes.wordDetail(entry.word.id)),
            padding: const EdgeInsets.all(FluiSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.word.lemma,
                        style: FluiTypography.h3.copyWith(
                          color: FluiColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: FluiSpacing.xxs),
                      Text(
                        entry.word.explanation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FluiTypography.body.copyWith(
                          color: FluiColors.gray,
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FluiSpacing.sm),
                StateChip(state: entry.progress.state.chipKind),
              ],
            ),
          ),
          const SizedBox(height: FluiSpacing.sm),
        ],
      ],
    );
  }
}
