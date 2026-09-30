import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/vocabulary/domain/exercises/production_check.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/features/vocabulary/presentation/widgets/spoken_answer_controls.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:material_ui/material_ui.dart';

/// Úsala (2/2): the user's own sentence (writing phase), then
/// "¿Suena natural?" (self-check).
///
/// During the writing phase, the sentence comes from the shell's mic
/// (`ProductionMicTarget`) via [SpokenAnswerControls] (design D36, U17b) —
/// [flow]'s own `sentence` (set by `ProductionFlow.submit`) shows what was
/// heard. The self-check phase is unaffected — it has never had a text
/// field.
class ProductionView extends StatefulWidget {
  const new({
    required this.flow,
    required this.lemma,
    required this.beforePhrase,
    required this.onConfirm,
    required this.onRevise,
    required this.onToggle,
    required this.onSkip,
    super.key,
    this.busy = false,
    this.micController,
  });

  final ProductionFlow flow;
  final String lemma;

  /// A vague phrase the word replaces, used as the situation.
  final String beforePhrase;
  final VoidCallback onConfirm;
  final VoidCallback onRevise;
  final ValueChanged<ProductionRubric> onToggle;
  final bool busy;

  /// Null only for the brief instant around sign-out/sign-in (mirrors
  /// `FluiBottomBar`'s own guard) — the mic controls stay empty rather
  /// than crashing.
  final MicController? micController;

  /// "Continuar sin hablar" — only offered while the mic is blocked
  /// (`SpokenAnswerControls` itself gates visibility).
  final VoidCallback onSkip;

  @override
  State<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends State<ProductionView> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flow = widget.flow;
    final issue = flow.issue;
    final type = context.type;
    final title = Semantics(
      header: true,
      child: Text(
        flow.phase == ProductionPhase.writing
            ? l10n.productionTitle
            : l10n.productionSelfCheckTitle,
        style: type.titleL.copyWith(color: FluiColors.charcoal),
      ),
    );

    if (flow.phase != ProductionPhase.writing) {
      final model = flow.modelSentence;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: FluiSpacing.xs),
          Text(
            l10n.productionSelfCheckBody,
            style: type.body.copyWith(color: FluiColors.gray),
          ),
          const SizedBox(height: FluiSpacing.lg),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: FluiColors.greenTint,
              borderRadius: FluiRadii.cardAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.lg),
              child: HighlightedText(
                text: '«${flow.sentence}»',
                forms: flow.forms,
                style: type.bodyL.copyWith(color: FluiColors.charcoal),
              ),
            ),
          ),
          if (model != null) ...[
            const SizedBox(height: FluiSpacing.lg),
            Text(
              l10n.productionModelTitle,
              style: type.label.copyWith(color: FluiColors.gray),
            ),
            const SizedBox(height: FluiSpacing.xxs),
            HighlightedText(
              text: '«$model»',
              forms: flow.forms,
              style: type.body.copyWith(color: FluiColors.gray),
            ),
          ],
          const SizedBox(height: FluiSpacing.lg),
          for (final item in ProductionRubric.values)
            _RubricTile(
              label: switch (item) {
                ProductionRubric.meaning => l10n.productionRubricMeaning,
                ProductionRubric.natural => l10n.productionRubricNatural,
                ProductionRubric.fits => l10n.productionRubricFits,
              },
              checked: flow.confirmed.contains(item),
              onChanged: widget.busy ? null : () => widget.onToggle(item),
            ),
          if (!flow.isRubricComplete) ...[
            const SizedBox(height: FluiSpacing.xs),
            Text(
              l10n.productionRubricPending,
              style: type.body.copyWith(color: FluiColors.gray),
            ),
          ],
          const SizedBox(height: FluiSpacing.lg),
          FluiButton.primary(
            label: l10n.productionYes,
            isLoading: widget.busy,
            onPressed: flow.isRubricComplete ? widget.onConfirm : null,
          ),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.productionNo,
            onPressed: widget.busy ? null : widget.onRevise,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: FluiSpacing.xs),
        Text(
          l10n.productionPrompt(widget.beforePhrase, widget.lemma),
          style: type.bodyL.copyWith(color: FluiColors.charcoal),
        ),
        const SizedBox(height: FluiSpacing.lg),
        if (widget.micController case final controller?) ...[
          if (_issueMessage(issue, l10n, widget.lemma) case final message?) ...[
            FluiNotice(message: message),
            const SizedBox(height: FluiSpacing.sm),
          ],
          SpokenAnswerControls(
            controller: controller,
            heardText: flow.sentence.isEmpty ? null : flow.sentence,
            onSkip: widget.onSkip,
          ),
        ],
      ],
    );
  }

  static String? _issueMessage(
    ProductionIssue? issue,
    AppLocalizations l10n,
    String lemma,
  ) => switch (issue) {
    ProductionIssue.tooShort => l10n.productionTooShort,
    ProductionIssue.missingWord => l10n.productionMissingWord(lemma),
    ProductionIssue.repeated => l10n.productionRepeatedWords,
    ProductionIssue.copiedModel => l10n.productionTooSimilar,
    null => null,
  };
}

/// One rubric line: a checkbox the user ticks about their own sentence.
class _RubricTile extends StatelessWidget {
  const new({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: FluiRadii.chipAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FluiSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: onChanged == null ? null : (_) => onChanged!(),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: FluiSpacing.sm),
                child: Text(
                  label,
                  style: context.type.body.copyWith(color: FluiColors.charcoal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
