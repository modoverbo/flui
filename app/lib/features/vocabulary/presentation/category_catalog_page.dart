import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/themes/presentation/widgets/theme_explorer_sheet.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/category_catalog_projection.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Theme;

/// Published vocabulary for one existing theme family.
class CategoryCatalogPage extends ConsumerStatefulWidget {
  const new({
    required this.familySlug,
    this.initialThemeId,
    this.initialScrollOffset = 0,
    super.key,
  });

  final String familySlug;
  final String? initialThemeId;
  final double initialScrollOffset;

  @override
  ConsumerState<CategoryCatalogPage> createState() =>
      _CategoryCatalogPageState();
}

class _CategoryCatalogPageState extends ConsumerState<CategoryCatalogPage> {
  late String? _selectedThemeId;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.initialThemeId;
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ThemeFamily? get _family {
    for (final family in ThemeFamily.values) {
      if (family.name == widget.familySlug) return family;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final family = _family;
    if (family == null) {
      return _statePage(
        title: l10n.categoryCatalogInvalid,
        message: '',
        actionLabel: l10n.commonBack,
        onAction: () => _goBack(context),
      );
    }

    final catalog = ref.watch(catalogProvider);
    final themes = ref.watch(themesProvider);
    if (catalog.hasError || themes.hasError) {
      return _statePage(
        title: l10n.categoryCatalogError,
        message: l10n.errorUnexpected,
        actionLabel: l10n.commonRetry,
        onAction: () {
          ref
            ..invalidate(catalogProvider)
            ..invalidate(themesProvider);
        },
      );
    }
    if (!catalog.hasValue || !themes.hasValue) {
      return Scaffold(
        backgroundColor: FluiColors.paper,
        body: Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
      );
    }

    final allThemes = themes.requireValue;
    final familyThemes = [
      for (final theme in allThemes)
        if (theme.family == family) theme,
    ];
    final grouped = projectPublishedWordsByFamily(
      themes: allThemes,
      catalog: catalog.requireValue,
    );
    final familyWords = grouped[family] ?? const <Word>[];
    final selected = _selectedThemeId;
    final filteredWords = selected == null
        ? familyWords
        : [
            for (final word in familyWords)
              if (word.themeIds.contains(selected)) word,
          ];
    final label = themeFamilyLabel(l10n, family);

    return Scaffold(
      backgroundColor: FluiColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: FluiSpacing.md),
                Semantics(
                  button: true,
                  label: l10n.commonBack,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: l10n.commonBack,
                      onPressed: () => _goBack(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: FluiSpacing.sm),
                FluiLabel(label),
                const SizedBox(height: FluiSpacing.xs),
                Text(
                  l10n.categoryCatalogTitle(label),
                  style: context.type.titleL.copyWith(color: FluiColors.ink),
                ),
                const SizedBox(height: FluiSpacing.sm),
                Text(
                  l10n.categoryCatalogWordCount(familyWords.length),
                  style: context.type.body.copyWith(color: FluiColors.gray),
                ),
                if (familyThemes.isNotEmpty) ...[
                  const SizedBox(height: FluiSpacing.md),
                  ChoiceChips<String?>(
                    values: [null, for (final theme in familyThemes) theme.id],
                    selected: selected,
                    labelOf: (id) => id == null
                        ? l10n.categoryCatalogAll
                        : familyThemes
                              .firstWhere((theme) => theme.id == id)
                              .name,
                    onSelected: (id) => setState(() => _selectedThemeId = id),
                  ),
                ],
                const SizedBox(height: FluiSpacing.lg),
                if (filteredWords.isEmpty)
                  EmptyState(
                    title: selected == null
                        ? l10n.categoryCatalogEmpty
                        : l10n.categoryCatalogFilteredEmpty,
                    message: '',
                  )
                else
                  for (final word in filteredWords) ...[
                    _CategoryWordCard(
                      word: word,
                      onTap: () => context.go(
                        AppRoutes.wordDetailFromCategory(
                          wordId: word.id,
                          returnLocation: AppRoutes.categoryCatalog(
                            family.name,
                            themeId: _selectedThemeId,
                            scrollOffset: _scrollController.hasClients
                                ? _scrollController.offset
                                : widget.initialScrollOffset,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: FluiSpacing.sm),
                  ],
                const SizedBox(height: FluiSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statePage({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) => Scaffold(
    backgroundColor: FluiColors.paper,
    body: SafeArea(
      child: SingleChildScrollView(
        child: PageFrame(
          child: Padding(
            padding: const EdgeInsets.only(top: FluiSpacing.xl),
            child: EmptyState(
              title: title,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ),
        ),
      ),
    ),
  );

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.today);
    }
  }
}

class _CategoryWordCard extends StatelessWidget {
  const new({required this.word, required this.onTap});

  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: '${word.lemma}. ${l10n.categoryCatalogOpenWord}',
      child: FluiCard(
        onTap: onTap,
        color: FluiColors.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.lemma,
                    style: context.type.titleM.copyWith(color: FluiColors.ink),
                  ),
                  const SizedBox(height: FluiSpacing.xs),
                  Text(
                    word.exampleSentence,
                    style: context.type.body.copyWith(color: FluiColors.gray),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            const Icon(Icons.arrow_outward_rounded),
          ],
        ),
      ),
    );
  }
}
