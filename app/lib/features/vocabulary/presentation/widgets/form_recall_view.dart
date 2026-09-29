import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/vocabulary/domain/exercises/form_recall_check.dart';
import 'package:flui/features/vocabulary/presentation/widgets/spoken_answer_controls.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Úsala (1/2): recall the word from its meaning and a masked sentence.
///
/// Typed ([onSubmit], via `FluiTextField`) by default; while [speakingGym]
/// is on (design D36, U17b), the field and its submit button are replaced
/// by [SpokenAnswerControls] — the answer comes from the shell's mic
/// (`FormRecallMicTarget`) instead, and [check]'s own `lastHeard` shows
/// what was heard. Hint/reveal/continue stay taps either way.
class FormRecallView extends StatefulWidget {
  const new({
    required this.check,
    required this.explanation,
    required this.syllableCount,
    required this.onSubmit,
    required this.onHint,
    required this.onContinue,
    super.key,
    this.sentenceBefore,
    this.sentenceAfter,
    this.busy = false,
    this.speakingGym = false,
    this.micController,
    this.onSkip,
  });

  final FormRecallCheck check;
  final String explanation;
  final String? sentenceBefore;
  final String? sentenceAfter;
  final int syllableCount;
  final ValueChanged<String> onSubmit;
  final VoidCallback onHint;
  final VoidCallback onContinue;
  final bool busy;

  /// U17b: shows [SpokenAnswerControls] instead of the typed field/button.
  final bool speakingGym;

  /// Required (and used) only while [speakingGym] is on.
  final MicController? micController;

  /// "Continuar sin hablar" — only offered while the mic is blocked
  /// (`SpokenAnswerControls` itself gates visibility). Required only while
  /// [speakingGym] is on.
  final VoidCallback? onSkip;

  @override
  State<FormRecallView> createState() => _FormRecallViewState();
}

class _FormRecallViewState extends State<FormRecallView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final check = widget.check;
    final before = widget.sentenceBefore;
    final after = widget.sentenceAfter;
    final type = context.type;
    final body = type.body.copyWith(color: FluiColors.charcoal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.formRecallTitle,
            style: type.titleL.copyWith(color: FluiColors.charcoal),
          ),
        ),
        const SizedBox(height: FluiSpacing.xs),
        Text(
          before == null ? l10n.formRecallMeaningOnly : l10n.formRecallBody,
          style: type.body.copyWith(color: FluiColors.gray),
        ),
        const SizedBox(height: FluiSpacing.lg),
        Text(widget.explanation, style: body),
        if (before != null && after != null) ...[
          const SizedBox(height: FluiSpacing.md),
          Semantics(
            label: '$before${l10n.clozeBlankSemantics}$after',
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(
                style: type.bodyL.copyWith(color: FluiColors.charcoal),
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: check.status == FormRecallStatus.pending
                        ? '________'
                        : check.expectedForm,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: FluiColors.greenDeep,
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: FluiSpacing.lg),
        if (!widget.speakingGym)
          FluiTextField(
            label: l10n.formRecallFieldLabel,
            controller: _controller,
            enabled: check.status == FormRecallStatus.pending && !widget.busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          )
        else if (widget.micController case final controller?)
          SpokenAnswerControls(
            controller: controller,
            heardText: check.lastHeard,
            onSkip: widget.onSkip ?? () {},
          ),
        if (check.hintsUsed >= 1) ...[
          const SizedBox(height: FluiSpacing.sm),
          FluiNotice(
            icon: LucideIcons.lightbulb,
            message: [
              l10n.formRecallHintSyllables(widget.syllableCount),
              if (check.hintsUsed >= 2)
                l10n.formRecallHintFirstLetter(check.firstLetter),
            ].join(' '),
          ),
        ],
        if (check.status == FormRecallStatus.pending &&
            check.lastAnswerRejected) ...[
          const SizedBox(height: FluiSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.formRecallRejected,
              style: type.bodyL.copyWith(
                color: FluiColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (check.status == FormRecallStatus.accepted) ...[
          const SizedBox(height: FluiSpacing.sm),
          FluiNotice(
            tone: FluiNoticeTone.info,
            message: l10n.formRecallAccepted,
          ),
        ],
        if (check.status == FormRecallStatus.revealed) ...[
          const SizedBox(height: FluiSpacing.sm),
          FluiNotice(
            tone: FluiNoticeTone.info,
            icon: LucideIcons.sparkles,
            message: l10n.formRecallRevealed(check.expectedForm),
          ),
        ],
        const SizedBox(height: FluiSpacing.lg),
        if (check.isResolved)
          FluiButton.primary(
            label: l10n.commonContinue,
            isLoading: widget.busy,
            onPressed: widget.onContinue,
          )
        else ...[
          if (!widget.speakingGym) ...[
            FluiButton.primary(
              label: l10n.formRecallCheck,
              isLoading: widget.busy,
              onPressed: _submit,
            ),
            const SizedBox(height: FluiSpacing.xs),
          ],
          Center(
            child: FluiButton.text(
              label: check.hintsUsed >= FormRecallCheck.maxHints
                  ? l10n.formRecallReveal
                  : l10n.formRecallHint,
              icon: LucideIcons.lightbulb,
              onPressed: widget.busy ? null : widget.onHint,
            ),
          ),
        ],
      ],
    );
  }
}
