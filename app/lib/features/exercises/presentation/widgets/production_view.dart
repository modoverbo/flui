import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/exercises/domain/production_check.dart';
import 'package:flui/features/vocabulary/presentation/widgets/highlighted_text.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:material_ui/material_ui.dart';

/// Úsala (2/2): the user's own sentence, then "¿Suena natural?".
class ProductionView extends StatefulWidget {
  const new({
    required this.flow,
    required this.lemma,
    required this.beforePhrase,
    required this.onSubmit,
    required this.onConfirm,
    required this.onRevise,
    super.key,
    this.busy = false,
  });

  final ProductionFlow flow;
  final String lemma;

  /// A vague phrase the word replaces, used as the situation.
  final String beforePhrase;
  final ValueChanged<String> onSubmit;
  final VoidCallback onConfirm;
  final VoidCallback onRevise;
  final bool busy;

  @override
  State<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends State<ProductionView> {
  late final _controller = TextEditingController(text: widget.flow.sentence);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flow = widget.flow;
    final issue = flow.issue;
    final title = Semantics(
      header: true,
      child: Text(
        flow.phase == ProductionPhase.writing
            ? l10n.productionTitle
            : l10n.productionSelfCheckTitle,
        style: FluiTypography.h2.copyWith(color: FluiColors.charcoal),
      ),
    );

    if (flow.phase != ProductionPhase.writing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: FluiSpacing.xs),
          Text(
            l10n.productionSelfCheckBody,
            style: FluiTypography.body.copyWith(color: FluiColors.gray),
          ),
          const SizedBox(height: FluiSpacing.lg),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: FluiColors.greenTint,
              borderRadius: FluiRadii.lgAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.lg),
              child: HighlightedText(
                text: '«${flow.sentence}»',
                forms: flow.forms,
                style: FluiTypography.body.copyWith(
                  color: FluiColors.charcoal,
                  fontSize: 18,
                  height: 28 / 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: FluiSpacing.xl),
          FluiButton.primary(
            label: l10n.productionYes,
            isLoading: widget.busy,
            onPressed: widget.onConfirm,
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
          style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
        ),
        const SizedBox(height: FluiSpacing.lg),
        FluiTextField(
          label: l10n.productionFieldLabel,
          controller: _controller,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmit,
          errorText: switch (issue) {
            ProductionIssue.tooShort => l10n.productionTooShort,
            ProductionIssue.missingWord => l10n.productionMissingWord(
              widget.lemma,
            ),
            null => null,
          },
        ),
        const SizedBox(height: FluiSpacing.lg),
        FluiButton.primary(
          label: l10n.productionSubmit,
          isLoading: widget.busy,
          onPressed: () => widget.onSubmit(_controller.text),
        ),
      ],
    );
  }
}
