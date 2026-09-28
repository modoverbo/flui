import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_gate.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The mandatory diagnosis's own entry screen (design part-3 §11 gate,
/// U14a): why + 3 steps + the consent question (only while
/// `audio_retention_consent` is unanswered) + a sign-out exit, since the
/// gate blocks the rest of the app until diagnosis is complete.
///
/// Root-navigator, outside the shell — no chrome, no mic dock (capture
/// starts on `DiagnosisPage`, the next screen).
class DiagnosisIntroPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final signingOut = ref.watch(signOutControllerProvider);
    final consent = ref.watch(_consentProvider);
    // A retake continuation (gate already `completed`) must keep the
    // `?retake=1` query param, or the router's own rule 5 would immediately
    // bounce `/diagnosis/live` back to `/today` (design part-3 §11).
    final isRetake =
        ref.watch(diagnosisGateProvider) == DiagnosisGate.completed;
    final asyncResume = ref.watch(diagnosisResumeProvider);
    final resume = asyncResume.value;
    final answered = resume is DiagnosisResume ? resume.answered.length : 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame.column(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: FluiSpacing.lg),
                PageHeader(
                  title: l10n.diagnosisIntroTitle,
                  subtitle: l10n.diagnosisIntroBody,
                ),
                const SizedBox(height: FluiSpacing.lg),
                FluiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.diagnosisIntroStep1),
                      const SizedBox(height: FluiSpacing.sm),
                      Text(l10n.diagnosisIntroStep2),
                      const SizedBox(height: FluiSpacing.sm),
                      Text(l10n.diagnosisIntroStep3),
                    ],
                  ),
                ),
                if (resume is DiagnosisResume) ...[
                  const SizedBox(height: FluiSpacing.lg),
                  FluiCard(
                    child: Text(l10n.diagnosisIntroResumeProgress(answered, 3)),
                  ),
                ],
                const SizedBox(height: FluiSpacing.lg),
                consent.when(
                  data: (granted) => granted == null
                      ? _ConsentQuestion(l10n: l10n)
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: FluiSpacing.lg),
                FluiButton.primary(
                  label: resume is DiagnosisResume
                      ? l10n.diagnosisIntroContinue
                      : l10n.diagnosisIntroStart,
                  onPressed: () => context.go(
                    isRetake
                        ? '${AppRoutes.diagnosisLive}?retake=1'
                        : AppRoutes.diagnosisLive,
                  ),
                ),
                const SizedBox(height: FluiSpacing.lg),
                FluiButton.text(
                  label: l10n.diagnosisIntroSignOut,
                  isLoading: signingOut,
                  onPressed: () =>
                      ref.read(signOutControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether audio-retention consent has been asked yet (`null` = not asked).
// ignore: specify_nonobvious_property_types
final _consentProvider = FutureProvider.autoDispose<bool?>((ref) async {
  final result = await ref.read(audioConsentRepositoryProvider).read();
  return result.valueOrNull;
});

class _ConsentQuestion extends ConsumerWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FluiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.diagnosisIntroConsentQuestion),
        const SizedBox(height: FluiSpacing.sm),
        Row(
          children: [
            Expanded(
              child: FluiButton.outline(
                label: l10n.diagnosisIntroConsentDecline,
                onPressed: () => _answer(ref, granted: false),
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: FluiButton.primary(
                label: l10n.diagnosisIntroConsentAccept,
                onPressed: () => _answer(ref, granted: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _answer(WidgetRef ref, {required bool granted}) {
    unawaited(ref.read(audioConsentRepositoryProvider).write(granted: granted));
    ref.invalidate(_consentProvider);
  }
}
