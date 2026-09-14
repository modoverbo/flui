import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/my_words.dart';
import 'package:flui/features/vocabulary/presentation/word_state_kind.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// The domain entity is called Theme, like Flutter's inherited widget; this
// screen needs the entity, never the widget.
import 'package:material_ui/material_ui.dart' hide Theme;

/// "Palabras": the repertoire, filterable by state. Two columns on a wide
/// window, so the list uses the page instead of a strip down the middle.
class WordsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends ConsumerState<WordsPage> {
  WordState? _filter;
  String? _themeFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final words = ref.watch(myWordsProvider);
    final themes = ref.watch(themesByIdProvider).value ?? const {};

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: layout.blockGap),
                switch (words) {
                  AsyncValue(hasValue: true, :final value?) => PageHeader(
                    title: l10n.navWords,
                    subtitle: value.isEmpty
                        ? l10n.wordsSubtitle
                        : l10n.wordsCountLabel(value.length),
                  ),
                  _ => PageHeader(
                    title: l10n.navWords,
                    subtitle: l10n.wordsSubtitle,
                  ),
                },
                SizedBox(height: layout.blockGap),
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
                    themes: themes,
                    themeFilter: _themeFilter,
                    onThemeFilter: (id) => setState(() => _themeFilter = id),
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
                SizedBox(height: layout.sectionGap),
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
    required this.themes,
    required this.themeFilter,
    required this.onThemeFilter,
  });

  final List<WordEntry> entries;
  final WordState? filter;
  final ValueChanged<WordState?> onFilter;

  /// The taxonomy, for naming a theme chip.
  final Map<String, Theme> themes;
  final String? themeFilter;
  final ValueChanged<String?> onThemeFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    // Only the themes the user actually has words in: a filter that returns
    // nothing on every chip is a worse list, not a longer one.
    final themeIds = [
      for (final theme
          in themes.values.toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        if (entries.any((e) => e.word.themeIds.contains(theme.id))) theme.id,
    ];
    final visible = [
      for (final entry in entries)
        if ((filter == null || entry.progress.state == filter) &&
            (themeFilter == null || entry.word.themeIds.contains(themeFilter)))
          entry,
    ];
    final columns = layout.isWide ? 2 : 1;

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
        if (themeIds.isNotEmpty) ...[
          const SizedBox(height: FluiSpacing.xs),
          ChoiceChips<String?>(
            values: [null, ...themeIds],
            selected: themeFilter,
            labelOf: (id) =>
                id == null ? l10n.wordsFilterThemeAll : themes[id]!.name,
            onSelected: onThemeFilter,
          ),
        ],
        SizedBox(height: layout.blockGap),
        if (visible.isEmpty)
          Text(
            themeFilter == null
                ? l10n.wordsFilterEmpty
                : l10n.wordsFilterThemeEmpty,
            style: layout.type.bodyL.copyWith(color: FluiColors.gray),
          )
        else
          Wrap(
            spacing: FluiSpacing.sm,
            runSpacing: FluiSpacing.sm,
            children: [
              for (final entry in visible)
                LayoutBuilder(
                  builder: (context, _) =>
                      _WordRow(entry: entry, columns: columns),
                ),
            ],
          ),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const new({required this.entry, required this.columns});

  final WordEntry entry;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final width = columns == 1
        ? double.infinity
        : (FluiSpacing.pageMaxWidth -
                  FluiSpacing.gutterWide * 2 -
                  FluiSpacing.sm) /
              2;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: SizedBox(
        width: columns == 1 ? double.infinity : width,
        child: Material(
          color: FluiColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: FluiRadii.cardAll,
            side: FluiSurfaces.hairlineOnCream,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go(AppRoutes.wordDetail(entry.word.id)),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.word.lemma,
                          style: type.titleM.copyWith(
                            color: FluiColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: FluiSpacing.xxs),
                        Text(
                          entry.word.explanation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.body.copyWith(color: FluiColors.gray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FluiSpacing.sm),
                  StateChip(state: entry.progress.state.chipKind),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
