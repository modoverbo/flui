import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/id/id_providers.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/training/presentation/widgets/training_loop_view.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// ENTRENAR: 4 training-mode cards (spec `training-lab`, U16 — replaces the
/// retired Habla/speaking-challenge tab). Selecting a mode navigates to
/// [AppRoutes.trainMode], which picks a published training challenge for
/// that mode and starts the shared training loop with `context = lab`.
///
/// Owns NO record affordance, permission handling, or hold-timer logic of
/// its own, and registers no lab-specific fallback mic target — capture
/// happens exclusively through the shell's single mic (decision #448/
/// #450.3); this page only navigates.
class TrainingLabPage extends StatelessWidget {
  const new({super.key});

  static const List<(TrainingMode, FluiGlyph)> _cards = [
    (TrainingMode.thinkAndSpeak, FluiGlyph.onda),
    (TrainingMode.speakWithPrecision, FluiGlyph.register),
    (TrainingMode.masterYourVoice, FluiGlyph.microphone),
    (TrainingMode.realSituations, FluiGlyph.inContext),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame.column(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: FluiSpacing.lg),
                PageHeader(title: l10n.navTrain, subtitle: l10n.trainSubtitle),
                const SizedBox(height: FluiSpacing.lg),
                for (final (mode, glyph) in _cards) ...[
                  _ModeCard(
                    glyph: glyph,
                    title: _titleFor(l10n, mode),
                    subtitle: _subtitleFor(l10n, mode),
                    onTap: () => context.go(AppRoutes.trainMode(mode)),
                  ),
                  const SizedBox(height: FluiSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _titleFor(AppLocalizations l10n, TrainingMode mode) =>
      switch (mode) {
        TrainingMode.thinkAndSpeak => l10n.trainModeThinkAndSpeakTitle,
        TrainingMode.speakWithPrecision =>
          l10n.trainModeSpeakWithPrecisionTitle,
        TrainingMode.masterYourVoice => l10n.trainModeMasterYourVoiceTitle,
        TrainingMode.realSituations => l10n.trainModeRealSituationsTitle,
      };

  static String _subtitleFor(AppLocalizations l10n, TrainingMode mode) =>
      switch (mode) {
        TrainingMode.thinkAndSpeak => l10n.trainModeThinkAndSpeakSubtitle,
        TrainingMode.speakWithPrecision =>
          l10n.trainModeSpeakWithPrecisionSubtitle,
        TrainingMode.masterYourVoice => l10n.trainModeMasterYourVoiceSubtitle,
        TrainingMode.realSituations => l10n.trainModeRealSituationsSubtitle,
      };
}

class _ModeCard extends StatelessWidget {
  const new({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final FluiGlyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: FluiCard(
        onTap: onTap,
        child: Row(
          children: [
            FluiGlyphIcon(glyph, size: FluiIconSize.tab, color: FluiColors.ink),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: type.titleM.copyWith(color: FluiColors.ink),
                  ),
                  const SizedBox(height: FluiSpacing.xxs),
                  Text(
                    subtitle,
                    style: type.body.copyWith(color: FluiColors.gray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The challenge a [TrainingMode]'s training-lab loop answers: the lowest
/// `sortOrder` published training challenge for that mode — the same
/// sort-order tie-break `TrainingPlanner` uses for its own challenge pick.
///
/// **Deviation (documented, see apply-progress)**: unlike
/// `TrainingPlanner._pickChallenge`, this has no "used in the last 7 days"
/// exclusion — that needs a `SpeakingAttemptRepository` query the port does
/// not expose yet (only `insert`, see `speaking_attempt_repository.dart`).
/// U16's own acceptance criteria never test recency exclusion; adding that
/// query is left to whichever later unit first needs it.
// ignore: specify_nonobvious_property_types
final labChallengeProvider = FutureProvider.autoDispose
    .family<Challenge?, TrainingMode>((ref, mode) async {
      final result = await ref.read(challengeRepositoryProvider).fetchCatalog();
      final catalog = result.valueOrNull ?? const <Challenge>[];
      final candidates =
          catalog
              .where(
                (challenge) => challenge.purpose == ChallengePurpose.training,
              )
              .where((challenge) => challenge.mode == mode)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return candidates.firstOrNull;
    });

/// One training-lab session's id, generated once per `(mode)` and kept
/// stable for as long as something watches it (autoDispose): every
/// `submit()` on the resulting [TrainingLoopController] shares it.
// ignore: specify_nonobvious_property_types
final labSessionIdProvider = Provider.autoDispose.family<String, TrainingMode>(
  (ref, mode) => ref.read(idGeneratorProvider).generate(),
);

/// The training loop for one ENTRENAR mode (`AppRoutes.trainMode`), reached
/// from [TrainingLabPage]. Hands off entirely to the shared
/// [TrainingLoopView] (`context = lab`, `LoopScript.full()`) once a
/// challenge is picked; shows [EmptyState] when the published catalog has
/// nothing for this mode yet (an empty catalog, never a crash).
class TrainingLabModePage extends ConsumerWidget {
  const new({required this.mode, super.key});

  final TrainingMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final asyncChallenge = ref.watch(labChallengeProvider(mode));
    return Scaffold(
      body: SafeArea(
        child: asyncChallenge.when(
          data: (challenge) => challenge == null
              ? Center(
                  child: EmptyState(
                    title: l10n.trainUnavailableTitle,
                    message: l10n.trainUnavailableBody,
                  ),
                )
              : TrainingLoopView(
                  request: LoopRequest(
                    context: TrainingContext.lab,
                    sessionId: ref.watch(labSessionIdProvider(mode)),
                    script: const LoopScript.full(),
                    challengeId: challenge.id,
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: EmptyState(
              title: l10n.trainUnavailableTitle,
              message: l10n.trainUnavailableBody,
            ),
          ),
        ),
      ),
    );
  }
}
