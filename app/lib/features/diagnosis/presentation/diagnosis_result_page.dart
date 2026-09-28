import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/presentation/behavior_code_copy.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The diagnosis result (design part-3 §7, §11, U14a): the computed
/// [SkillProfile] rendered as sentences — never a number, never a raw wire
/// code. Reads the just-published profile from [latestSkillProfileProvider]
/// (set by `DiagnosisPage`'s own successful save) rather than a route
/// parameter, so a direct/refreshed visit re-reads the real persisted
/// state instead of ever fabricating one.
class DiagnosisResultPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final userId = ref.watch(currentUserIdProvider);
    final asyncRecord = userId == null
        ? const AsyncValue<SkillProfileRecord?>.data(null)
        : ref.watch(latestSkillProfileProvider(userId));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame.column(
            child: switch (asyncRecord) {
              AsyncValue(hasValue: true, :final value) when value != null =>
                _ResultBody(profile: value.profile, l10n: l10n),
              AsyncValue(hasValue: true) || AsyncError() => EmptyState(
                title: l10n.diagnosisResultUnavailable,
                message: l10n.diagnosisUnavailableBody,
                actionLabel: l10n.diagnosisRetryAction,
                onAction: () => context.go(AppRoutes.diagnosis),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const new({required this.profile, required this.l10n});

  final SkillProfile profile;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final strengths = profile.strengths;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FluiSpacing.lg),
        PageHeader(title: l10n.diagnosisResultTitle),
        const SizedBox(height: FluiSpacing.lg),
        FluiLabel(l10n.diagnosisResultTopLabel),
        const SizedBox(height: FluiSpacing.xs),
        FluiCard(
          color: FluiColors.aqua,
          child: Text(_areaLine(l10n, profile.topArea, profile.topBehavior)),
        ),
        const SizedBox(height: FluiSpacing.md),
        FluiLabel(l10n.diagnosisResultSecondLabel),
        const SizedBox(height: FluiSpacing.xs),
        FluiCard(
          child: Text(
            _areaLine(l10n, profile.secondArea, profile.secondBehavior),
          ),
        ),
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: FluiSpacing.md),
          FluiLabel(l10n.diagnosisResultStrengthsLabel),
          const SizedBox(height: FluiSpacing.xs),
          for (final code in strengths) ...[
            FluiCard(child: Text(behaviorCodeLine(l10n, code))),
            const SizedBox(height: FluiSpacing.xs),
          ],
        ],
        const SizedBox(height: FluiSpacing.lg),
        FluiButton.primary(
          label: l10n.diagnosisResultContinue,
          onPressed: () => context.go(AppRoutes.today),
        ),
      ],
    );
  }

  static String _areaLine(
    AppLocalizations l10n,
    SkillArea area,
    BehaviorCode? behavior,
  ) => behavior == null
      ? _areaLabel(l10n, area)
      : behaviorCodeLine(l10n, behavior);

  static String _areaLabel(AppLocalizations l10n, SkillArea area) =>
      skillAreaLine(l10n, area);
}
