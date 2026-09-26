import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
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
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
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
  final _scrollOffset = ValueNotifier<double>(0);
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.initialThemeId;
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    )..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onScroll() {
    _scrollOffset.value = _scrollController.offset;
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: FluiColors.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            key: _viewportKey,
            height: constraints.maxHeight,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
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
                          style: context.type.titleL.copyWith(
                            color: FluiColors.ink,
                          ),
                        ),
                        const SizedBox(height: FluiSpacing.sm),
                        Text(
                          l10n.categoryCatalogWordCount(familyWords.length),
                          style: context.type.body.copyWith(
                            color: FluiColors.gray,
                          ),
                        ),
                        if (familyThemes.isNotEmpty) ...[
                          const SizedBox(height: FluiSpacing.md),
                          ChoiceChips<String?>(
                            values: [
                              null,
                              for (final theme in familyThemes) theme.id,
                            ],
                            selected: selected,
                            labelOf: (id) => id == null
                                ? l10n.categoryCatalogAll
                                : familyThemes
                                      .firstWhere((theme) => theme.id == id)
                                      .name,
                            onSelected: (id) =>
                                setState(() => _selectedThemeId = id),
                          ),
                        ],
                        const SizedBox(height: FluiSpacing.section),
                        if (filteredWords.isEmpty)
                          EmptyState(
                            title: selected == null
                                ? l10n.categoryCatalogEmpty
                                : l10n.categoryCatalogFilteredEmpty,
                            message: '',
                          ),
                      ],
                    ),
                  ),
                ),
                if (filteredWords.isNotEmpty)
                  SliverList.builder(
                    itemCount: filteredWords.length,
                    itemBuilder: (context, index) {
                      final word = filteredWords[index];
                      return PageFrame(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: FluiSpacing.xxs,
                          ),
                          child: _CategoryWordCard(
                            word: word,
                            family: family,
                            scrollOffset: _scrollOffset,
                            viewportKey: _viewportKey,
                            reduceMotion: reduceMotion,
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
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: FluiSpacing.xl),
                ),
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

class _CategoryWordCard extends StatefulWidget {
  const new({
    required this.word,
    required this.family,
    required this.scrollOffset,
    required this.viewportKey,
    required this.reduceMotion,
    required this.onTap,
  });

  final Word word;
  final ThemeFamily family;
  final ValueListenable<double> scrollOffset;
  final GlobalKey viewportKey;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  State<_CategoryWordCard> createState() => _CategoryWordCardState();
}

class _CategoryWordCardState extends State<_CategoryWordCard> {
  final GlobalKey _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final word = widget.word;
    return Semantics(
      button: true,
      label:
          '${word.lemma}. ${_partOfSpeechLabel(word.partOfSpeech)}. '
          '${_registerLabel(word.register)}. ${word.explanation}. '
          '${word.exampleSentence}. ${l10n.categoryCatalogOpenWord}',
      child: ValueListenableBuilder<double>(
        valueListenable: widget.scrollOffset,
        child: DecoratedBox(
          key: ValueKey<String>('category-card-shadow-${word.id}'),
          decoration: BoxDecoration(
            borderRadius: expressiveCardRadius,
            boxShadow: [
              BoxShadow(
                color: _familyAccent(widget.family).withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: FluiColors.ink.withValues(alpha: .08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FluiCard(
            key: _surfaceKey,
            onTap: widget.onTap,
            color: FluiColors.surface,
            padding: const EdgeInsets.all(FluiSpacing.md),
            child: _contents(context),
          ),
        ),
        builder: (context, _, child) => Transform(
          key: ValueKey<String>('category-word-${widget.word.id}'),
          alignment: Alignment.center,
          transform: _depthTransform(),
          child: child,
        ),
      ),
    );
  }

  Widget _contents(BuildContext context) {
    final type = context.type;
    final word = widget.word;
    final accent = _familyAccent(widget.family);
    final metadataStyle = type.label.copyWith(color: FluiColors.ink);
    final hasUsageTip = word.usageTip?.isNotEmpty == true;
    final teaserLabel = hasUsageTip ? 'Uso' : 'Ejemplo';
    final teaser = hasUsageTip ? word.usageTip! : word.exampleSentence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(FluiRadii.chip),
              ),
              child: const SizedBox(width: 5, height: 46),
            ),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.lemma,
                    style: type.titleM.copyWith(color: FluiColors.ink),
                  ),
                  const SizedBox(height: FluiSpacing.xs),
                  Wrap(
                    spacing: FluiSpacing.xs,
                    runSpacing: FluiSpacing.xs,
                    children: [
                      _MetadataPill(
                        label: _partOfSpeechLabel(word.partOfSpeech),
                        accent: accent,
                        textStyle: metadataStyle,
                      ),
                      _MetadataPill(
                        label: _registerLabel(word.register),
                        accent: accent,
                        textStyle: metadataStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Icon(Icons.arrow_outward_rounded, color: accent),
          ],
        ),
        const SizedBox(height: FluiSpacing.md),
        Text('Significado', style: metadataStyle),
        const SizedBox(height: FluiSpacing.xxs),
        Text(
          word.explanation,
          style: type.body.copyWith(color: FluiColors.ink),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: FluiSpacing.sm),
        Text(teaserLabel, style: metadataStyle),
        const SizedBox(height: FluiSpacing.xxs),
        DecoratedBox(
          key: ValueKey<String>('category-card-teaser-${word.id}'),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(FluiRadii.chip),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FluiSpacing.xs,
              vertical: FluiSpacing.xxs,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    hasUsageTip
                        ? Icons.lightbulb_outline_rounded
                        : Icons.format_quote_rounded,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: FluiSpacing.xs),
                Expanded(
                  child: Text(
                    teaser,
                    style: type.body.copyWith(color: FluiColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluiSpacing.lg),
      ],
    );
  }

  Matrix4 _depthTransform() {
    final transform = Matrix4.identity();
    if (widget.reduceMotion) return transform;

    final viewport = widget.viewportKey.currentContext?.findRenderObject();
    final card = _surfaceKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || card is! RenderBox || !viewport.hasSize) {
      return transform;
    }

    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final cardTop = card.localToGlobal(Offset.zero).dy;
    final viewportCenter = viewportTop + viewport.size.height / 2;
    final cardCenter = cardTop + card.size.height / 2;
    final normalizedDistance =
        ((cardCenter - viewportCenter) / (viewport.size.height / 2)).clamp(
          -1.0,
          1.0,
        );
    final distance = normalizedDistance.abs();
    final verticalHandoff = -normalizedDistance * 52;
    final depth = (1 - distance) * 24;

    return transform
      ..setEntry(3, 2, -0.0018)
      ..translateByDouble(0, verticalHandoff, depth, 1)
      ..rotateX(-normalizedDistance * 0.07)
      ..scaleByDouble(1 - distance * 0.035, 1 - distance * 0.035, 1, 1);
  }
}

class _MetadataPill extends StatelessWidget {
  const new({
    required this.label,
    required this.accent,
    required this.textStyle,
  });

  final String label;
  final Color accent;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(FluiRadii.chip),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FluiSpacing.xs,
        vertical: FluiSpacing.xxs,
      ),
      child: Text(label, style: textStyle),
    ),
  );
}

Color _familyAccent(ThemeFamily family) => switch (family) {
  ThemeFamily.trabajo => FluiColors.electricBlue,
  ThemeFamily.social => FluiColors.softPink,
  ThemeFamily.publico => FluiColors.aqua,
  ThemeFamily.precision => FluiColors.acidLime,
  ThemeFamily.emocion => FluiColors.lavender,
};

String _partOfSpeechLabel(PartOfSpeech partOfSpeech) => switch (partOfSpeech) {
  PartOfSpeech.adjetivo => 'Adjetivo',
  PartOfSpeech.adverbio => 'Adverbio',
  PartOfSpeech.conector => 'Conector',
  PartOfSpeech.sustantivo => 'Sustantivo',
  PartOfSpeech.verbo => 'Verbo',
};

String _registerLabel(WordRegister register) => switch (register) {
  WordRegister.neutral => 'Registro neutro',
  WordRegister.culto => 'Registro culto',
  WordRegister.coloquial => 'Registro coloquial',
};
