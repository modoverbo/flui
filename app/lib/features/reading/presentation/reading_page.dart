import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/scene_label.dart';
import 'package:flui/features/reading/presentation/widgets/reading_card.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "En contexto": scenes of today's and recently introduced words.
class ReadingPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends ConsumerState<ReadingPage> {
  Scene? _scene;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final readings = ref.watch(contextReadingsProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            maxWidth: FluiSpacing.appContentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: l10n.navContext,
                  subtitle: l10n.contextSubtitle,
                ),
                const SizedBox(height: FluiSpacing.lg),
                switch (readings) {
                  AsyncValue(hasValue: true, :final value?)
                      when value.isEmpty =>
                    EmptyState(
                      title: l10n.contextEmptyTitle,
                      message: l10n.contextEmptyBody,
                    ),
                  AsyncValue(hasValue: true, :final value?) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ChoiceChips<Scene?>(
                        values: const [null, ...Scene.values],
                        selected: _scene,
                        labelOf: (scene) => scene == null
                            ? l10n.contextFilterAll
                            : sceneLabel(l10n, scene),
                        onSelected: (scene) => setState(() => _scene = scene),
                      ),
                      const SizedBox(height: FluiSpacing.md),
                      for (final item in value)
                        if (_scene == null || item.reading.scene == _scene) ...[
                          Text(
                            item.word.lemma,
                            style: FluiTypography.label.copyWith(
                              color: FluiColors.greenSecondary,
                            ),
                          ),
                          const SizedBox(height: FluiSpacing.xxs),
                          ReadingCard(
                            reading: item.reading,
                            forms: item.word.forms,
                          ),
                          const SizedBox(height: FluiSpacing.md),
                        ],
                    ],
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
