import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/features/exercises/domain/cloze_attempt_flow.dart';
import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Elige: sentence with a blank, three option tiles and kind feedback.
///
/// One primary action at a time: "Confirmar", "Intentar de nuevo" after a
/// "Casi." hint, or "Continuar" once resolved.
class ClozeView extends StatefulWidget {
  const new({
    required this.flow,
    required this.onConfirm,
    required this.onRetry,
    required this.onContinue,
    super.key,
    this.label,
    this.busy = false,
  });

  final ClozeAttemptFlow flow;
  final ValueChanged<String> onConfirm;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  /// Context above the title, for example "Repaso".
  final String? label;
  final bool busy;

  @override
  State<ClozeView> createState() => _ClozeViewState();
}

class _ClozeViewState extends State<ClozeView> {
  String? _selectedId;

  @override
  void didUpdateWidget(ClozeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedId;
    if (oldWidget.flow.exercise.id != widget.flow.exercise.id ||
        (selected != null && !widget.flow.isEnabled(selected))) {
      _selectedId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flow = widget.flow;
    final feedback = flow.feedback;
    final resolution = flow.resolution;
    final label = widget.label;
    final selected = _selectedId;

    final Widget action;
    if (resolution != null) {
      action = FluiButton.primary(
        label: l10n.commonContinue,
        isLoading: widget.busy,
        onPressed: widget.onContinue,
      );
    } else if (feedback != null) {
      action = FluiButton.primary(
        label: l10n.clozeTryAgain,
        onPressed: widget.onRetry,
      );
    } else {
      action = FluiButton.primary(
        label: l10n.clozeConfirm,
        isLoading: widget.busy,
        onPressed: selected == null || !flow.isEnabled(selected)
            ? null
            : () {
                setState(() => _selectedId = null);
                widget.onConfirm(selected);
              },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: FluiTypography.label.copyWith(color: FluiColors.gray),
          ),
          const SizedBox(height: FluiSpacing.xxs),
        ],
        Semantics(
          header: true,
          child: Text(
            l10n.clozeTitle,
            style: FluiTypography.h2.copyWith(color: FluiColors.charcoal),
          ),
        ),
        const SizedBox(height: FluiSpacing.lg),
        _Sentence(exercise: flow.exercise, resolved: resolution != null),
        const SizedBox(height: FluiSpacing.lg),
        if (feedback != null)
          _AlmostPanel(hint: feedback)
        else ...[
          for (final option in flow.options) ...[
            _OptionTile(
              option: option,
              selected: option.id == selected,
              enabled: flow.isEnabled(option.id) && !widget.busy,
              discarded: flow.discardedOptionIds.contains(option.id),
              showAsAnswer: resolution != null && option.isCorrect,
              onTap: () => setState(() => _selectedId = option.id),
            ),
            const SizedBox(height: FluiSpacing.sm),
          ],
          if (flow.mustPickRemaining)
            Text(
              l10n.clozeOneLeft,
              style: FluiTypography.body.copyWith(color: FluiColors.gray),
            ),
          if (resolution != null) _ResolvedPanel(resolution: resolution),
        ],
        const SizedBox(height: FluiSpacing.lg),
        action,
      ],
    );
  }
}

class _Sentence extends StatelessWidget {
  const new({required this.exercise, required this.resolved});

  final ClozeExercise exercise;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final parts = exercise.sentenceParts;
    final style = FluiTypography.body.copyWith(
      color: FluiColors.charcoal,
      fontSize: 18,
      height: 28 / 18,
    );
    final blank = resolved ? exercise.correctOption.text : '________';
    return Semantics(
      label:
          '${parts.before}'
          '${resolved ? blank : context.l10n.clozeBlankSemantics}'
          '${parts.after}',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: parts.before),
            TextSpan(
              text: blank,
              style: style.copyWith(
                fontWeight: FontWeight.w700,
                color: resolved ? FluiColors.greenDeep : FluiColors.gray,
              ),
            ),
            TextSpan(text: parts.after),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const new({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.discarded,
    required this.showAsAnswer,
    required this.onTap,
  });

  final ExerciseOption option;
  final bool selected;
  final bool enabled;
  final bool discarded;
  final bool showAsAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = selected || showAsAnswer;
    final foreground = discarded ? FluiColors.gray : FluiColors.charcoal;
    return Semantics(
      button: true,
      selected: highlighted,
      enabled: enabled,
      label: discarded
          ? context.l10n.clozeOptionDiscarded(option.text)
          : option.text,
      excludeSemantics: true,
      child: Material(
        color: highlighted ? FluiColors.greenTint : FluiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: FluiRadii.lgAll,
          side: BorderSide(
            color: highlighted ? FluiColors.greenDeep : FluiColors.outline,
            width: highlighted ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FluiSpacing.md,
                vertical: FluiSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    showAsAnswer
                        ? LucideIcons.circle_check
                        : selected
                        ? LucideIcons.circle_dot
                        : LucideIcons.circle,
                    size: 20,
                    color: highlighted ? FluiColors.greenDeep : FluiColors.gray,
                  ),
                  const SizedBox(width: FluiSpacing.sm),
                  Expanded(
                    child: Text(
                      option.text,
                      style: FluiTypography.bodyEmphasis.copyWith(
                        color: foreground,
                        decoration: discarded
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlmostPanel extends StatelessWidget {
  const new({required this.hint});

  final ClozeHint hint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: FluiColors.yellowTint,
          borderRadius: FluiRadii.lgAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.clozeAlmost,
                style: FluiTypography.h1.copyWith(color: FluiColors.charcoal),
              ),
              const SizedBox(height: FluiSpacing.xxs),
              Text(
                l10n.clozeNotYet,
                style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
              ),
              const SizedBox(height: FluiSpacing.md),
              Row(
                children: [
                  const Icon(
                    LucideIcons.lightbulb,
                    size: 18,
                    color: FluiColors.charcoal,
                  ),
                  const SizedBox(width: FluiSpacing.xs),
                  Text(
                    l10n.clozeHint,
                    style: FluiTypography.label.copyWith(
                      color: FluiColors.charcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FluiSpacing.xxs),
              Text(
                hint.text,
                style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolvedPanel extends StatelessWidget {
  const new({required this.resolution});

  final ClozeResolution resolution;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = FluiTypography.body.copyWith(color: FluiColors.charcoal);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: FluiColors.greenTint,
          borderRadius: FluiRadii.lgAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolution.revealed ? l10n.clozeRevealed : l10n.clozeCorrect,
                style: FluiTypography.h2.copyWith(color: FluiColors.greenDeep),
              ),
              const SizedBox(height: FluiSpacing.xs),
              Text(resolution.explanation, style: body),
              if (resolution.whyNot.isNotEmpty) ...[
                const SizedBox(height: FluiSpacing.md),
                Text(
                  l10n.clozeWhyNotTitle,
                  style: FluiTypography.label.copyWith(
                    color: FluiColors.greenDeep,
                  ),
                ),
                for (final item in resolution.whyNot) ...[
                  const SizedBox(height: FluiSpacing.xs),
                  Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        TextSpan(
                          text: '${item.option}: ',
                          style: body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: item.reason),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
