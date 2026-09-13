import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/scene_label.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// "¿Dónde te traiciona el vocabulario?" — multi-select, on the plate.
class ContextsQuestion extends StatelessWidget {
  const new({required this.selected, required this.onToggle, super.key});

  final Set<Scene> selected;
  final ValueChanged<Scene> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _QuestionLayout(
      title: l10n.onboardingContextsQuestion,
      hint: l10n.onboardingContextsHint,
      children: [
        for (final scene in Scene.values)
          _Option(
            title: sceneLabel(l10n, scene),
            selected: selected.contains(scene),
            multiple: true,
            onTap: () => onToggle(scene),
          ),
      ],
    );
  }
}

/// "¿Cómo quieres sonar?" — single-select, on the plate.
class ToneQuestion extends StatelessWidget {
  const new({required this.selected, required this.onSelected, super.key});

  final SpeakingTone? selected;
  final ValueChanged<SpeakingTone> onSelected;

  static (String title, String body) labelsOf(
    AppLocalizations l10n,
    SpeakingTone tone,
  ) => switch (tone) {
    SpeakingTone.precise => (
      l10n.onboardingTonePrecise,
      l10n.onboardingTonePreciseBody,
    ),
    SpeakingTone.warm => (l10n.onboardingToneWarm, l10n.onboardingToneWarmBody),
    SpeakingTone.confident => (
      l10n.onboardingToneConfident,
      l10n.onboardingToneConfidentBody,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _QuestionLayout(
      title: l10n.onboardingToneQuestion,
      hint: l10n.onboardingToneHint,
      children: [
        for (final tone in SpeakingTone.values)
          Builder(
            builder: (context) {
              final (title, body) = labelsOf(l10n, tone);
              return _Option(
                title: title,
                body: body,
                selected: selected == tone,
                multiple: false,
                onTap: () => onSelected(tone),
              );
            },
          ),
      ],
    );
  }
}

class _QuestionLayout extends StatelessWidget {
  const new({required this.title, required this.hint, required this.children});

  final String title;
  final String hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final type = layout.type;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: layout.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: type.titleL.copyWith(color: FluiColors.cream),
            ),
          ),
          const SizedBox(height: FluiSpacing.xs),
          FluiLabel(hint, onDark: true),
          SizedBox(height: layout.blockGap),
          for (final child in children) ...[
            child,
            const SizedBox(height: FluiSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const new({
    required this.title,
    required this.selected,
    required this.multiple,
    required this.onTap,
    this.body,
  });

  final String title;
  final String? body;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final body = this.body;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: !multiple,
      label: body == null ? title : '$title. $body',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? FluiColors.greenSecondary
            : FluiColors.greenDeep.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: FluiRadii.cardAll,
          side: selected
              ? const BorderSide(color: FluiColors.yellowElectric, width: 2)
              : FluiSurfaces.hairlineOnGreen,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: FluiSpacing.minTapTarget + FluiSpacing.md,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FluiSpacing.md,
                vertical: FluiSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: type.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: FluiColors.cream,
                          ),
                        ),
                        if (body != null)
                          Text(
                            body,
                            style: type.body.copyWith(
                              color: FluiColors.creamMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FluiSpacing.sm),
                  if (selected)
                    const FluiGlyphIcon(
                      FluiGlyph.achievement,
                      color: FluiColors.yellowElectric,
                    )
                  else
                    const Icon(
                      LucideIcons.circle,
                      size: 20,
                      color: FluiColors.creamMuted,
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
