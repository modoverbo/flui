import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/shared/motion/feedback_motion.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:material_ui/material_ui.dart';

/// The aha before the account: one real word and one real swap.
///
/// The content is the bundled demo catalog, not the repository, so the step
/// works signed out, offline and on either backend.
class MicroLessonView extends StatefulWidget {
  const new({required this.onResolved, super.key, this.word});

  /// Called the first time the user resolves the swap.
  final VoidCallback onResolved;

  /// Defaults to the first demo word.
  final Word? word;

  @override
  State<MicroLessonView> createState() => _MicroLessonViewState();
}

class _MicroLessonViewState extends State<MicroLessonView> {
  String? _chosenId;
  var _wrongAttempts = 0;

  Word get _word => widget.word ?? seedWords.first;

  List<ExerciseOption> get _options {
    final exercise = _word.exercises.firstOrNull;
    if (exercise == null) return const [];
    return [...exercise.options]
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  bool get _solved =>
      _options.any((option) => option.id == _chosenId && option.isCorrect);

  void _choose(ExerciseOption option) {
    if (_solved) return;
    setState(() {
      _chosenId = option.id;
      if (!option.isCorrect) _wrongAttempts++;
    });
    if (option.isCorrect) widget.onResolved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;
    final word = _word;
    final replacement = word.replaces.firstOrNull;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: layout.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FluiLabel(l10n.onboardingLessonEyebrow),
          const SizedBox(height: FluiSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              l10n.onboardingLessonIntro,
              style: type.titleL.copyWith(color: FluiColors.charcoal),
            ),
          ),
          SizedBox(height: layout.blockGap),
          _WordCard(word: word),
          SizedBox(height: layout.blockGap),
          if (replacement != null) ...[
            Text(
              l10n.onboardingLessonPrompt,
              style: type.body.copyWith(color: FluiColors.gray),
            ),
            const SizedBox(height: FluiSpacing.xs),
            Text(
              '«${replacement.before}»',
              style: type.bodyL.copyWith(
                color: FluiColors.charcoal,
                decoration: _solved ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: FluiSpacing.md),
          ],
          ShakeBox(
            attempt: _wrongAttempts,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in _options) ...[
                  _OptionTile(
                    option: option,
                    chosen: option.id == _chosenId,
                    revealed: _solved,
                    onTap: () => _choose(option),
                  ),
                  const SizedBox(height: FluiSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: FluiSpacing.md),
          if (_solved && replacement != null)
            _Feedback(after: replacement.after, forms: word)
          else if (_wrongAttempts > 0)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.onboardingLessonAlmost,
                style: type.bodyL.copyWith(color: FluiColors.charcoal),
              ),
            ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const new({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluiColors.surface,
        borderRadius: FluiRadii.cardAll,
        border: FluiSurfaces.borderOnCream(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.ml),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FluiGlyphIcon(
                  FluiGlyph.wordOfTheDay,
                  color: FluiColors.greenSecondary,
                ),
                const SizedBox(width: FluiSpacing.xs),
                Expanded(child: FluiLabel(context.l10n.wordTodayBadge)),
              ],
            ),
            const SizedBox(height: FluiSpacing.sm),
            Text(
              word.lemma,
              style: type.titleL.copyWith(color: FluiColors.charcoal),
            ),
            const SizedBox(height: FluiSpacing.xs),
            Text(
              word.explanation,
              style: type.body.copyWith(color: FluiColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const new({
    required this.option,
    required this.chosen,
    required this.revealed,
    required this.onTap,
  });

  final ExerciseOption option;
  final bool chosen;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final right = revealed && option.isCorrect;
    final type = context.type;
    return Semantics(
      button: true,
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      label: option.text,
      excludeSemantics: true,
      child: Material(
        color: right ? FluiColors.greenTint : FluiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: FluiRadii.cardAll,
          side: BorderSide(
            color: right ? FluiColors.greenDeep : FluiColors.outline,
            width: right ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FluiSpacing.md,
                vertical: FluiSpacing.sm,
              ),
              child: DrawUnderline(
                drawn: right,
                child: Text(
                  option.text,
                  style: type.bodyL.copyWith(
                    color: FluiColors.charcoal,
                    fontWeight: right ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const new({required this.after, required this.forms});

  final String after;
  final Word forms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: FluiColors.greenTint,
          borderRadius: FluiRadii.cardAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(FluiSpacing.ml),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingLessonFeedback,
                style: type.titleM.copyWith(color: FluiColors.greenDeep),
              ),
              const SizedBox(height: FluiSpacing.xs),
              Text(
                '«$after»',
                style: type.bodyL.copyWith(
                  color: FluiColors.greenDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
