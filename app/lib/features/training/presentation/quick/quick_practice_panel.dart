import 'dart:async';

import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/feedback.dart' as domain;
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_target.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Feedback;

/// The quick-practice panel (design §19.13; decision #450.3): shown once
/// `QuickPracticeTarget`'s `MicPrepare` activates. Owns NO capture
/// affordance of its own — the shell's single mic is still the sole
/// trigger (decision #448); this only renders what phase the shared
/// training loop is in for the picked [challenge].
///
/// 4 phases (detail-mic §U23e step 7): think (prompt+cue+countdown) ->
/// ready ("toca el micrófono para responder") -> feedback -> summary. The
/// first two both correspond to [LoopPhase.focus] — the split is a purely
/// local, advisory 5s timer, not a loop state.
class QuickPracticePanel extends ConsumerStatefulWidget {
  const new({required this.request, required this.challenge, super.key});

  final LoopRequest request;
  final Challenge? challenge;

  /// The advisory "piensa unos segundos" window (design §19.13's
  /// `QuickPractice.thinkTime`) before the panel switches from the think
  /// view to the ready-to-record view. Purely visual — the mic itself is
  /// ready to record from the very start of this phase (design: "the mic
  /// READY immediately, no forced wait").
  static const thinkTime = Duration(seconds: 5);

  @override
  ConsumerState<QuickPracticePanel> createState() => _QuickPracticePanelState();
}

class _QuickPracticePanelState extends ConsumerState<QuickPracticePanel> {
  bool _thinking = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(QuickPracticePanel.thinkTime, () {
      if (mounted) setState(() => _thinking = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainingLoopControllerProvider(widget.request));
    final l10n = AppLocalizations.of(context);
    final body = switch (state.loop.phase) {
      LoopPhase.feedback => _FeedbackBody(
        l10n: l10n,
        feedback: state.feedback,
        onContinue: () => ref
            .read(trainingLoopControllerProvider(widget.request).notifier)
            .continueToNextStep(),
      ),
      LoopPhase.summary => _SummaryBody(l10n: l10n, feedback: state.feedback),
      _ when widget.challenge == null => _NoChallengeBody(l10n: l10n),
      _ =>
        _thinking
            ? _ThinkingBody(l10n: l10n, challenge: widget.challenge!)
            : _ReadyBody(l10n: l10n, challenge: widget.challenge!),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: FluiSpacing.md),
        _Actions(l10n: l10n),
      ],
    );
  }
}

class _ThinkingBody extends StatelessWidget {
  const new({required this.l10n, required this.challenge});

  final AppLocalizations l10n;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) => FluiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.quickPracticeThinkingHeadline,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: FluiSpacing.sm),
        Text(challenge.prompt),
        if (challenge.cue case final cue?) ...[
          const SizedBox(height: FluiSpacing.sm),
          Text(
            l10n.quickPracticeCueLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(cue),
        ],
      ],
    ),
  );
}

class _ReadyBody extends StatelessWidget {
  const new({required this.l10n, required this.challenge});

  final AppLocalizations l10n;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) => FluiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(challenge.prompt),
        const SizedBox(height: FluiSpacing.sm),
        Text(l10n.quickPracticeReadyHint),
      ],
    ),
  );
}

class _FeedbackBody extends StatelessWidget {
  const new({
    required this.l10n,
    required this.feedback,
    required this.onContinue,
  });

  final AppLocalizations l10n;
  final domain.Feedback? feedback;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => FluiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.quickPracticeFeedbackHeadline,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: FluiSpacing.sm),
        Text(feedback?.summary ?? ''),
        const SizedBox(height: FluiSpacing.sm),
        FluiButton.primary(
          label: l10n.loopContinueAction,
          onPressed: onContinue,
        ),
      ],
    ),
  );
}

class _SummaryBody extends StatelessWidget {
  const new({required this.l10n, required this.feedback});

  final AppLocalizations l10n;
  final domain.Feedback? feedback;

  @override
  Widget build(BuildContext context) => FluiCard(
    color: FluiColors.greenTint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.quickPracticeSummaryTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: FluiSpacing.sm),
        Text(l10n.quickPracticeSummaryBody),
        if (feedback != null) ...[
          const SizedBox(height: FluiSpacing.sm),
          Text(feedback!.summary),
        ],
      ],
    ),
  );
}

class _NoChallengeBody extends StatelessWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) =>
      FluiCard(child: Text(l10n.quickPracticeNoChallengeMessage));
}

/// "Otro reto" / "Cerrar" (design §19.13): free taps, no quota consumed.
class _Actions extends ConsumerWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      FluiButton.text(
        label: l10n.quickPracticeCloseAction,
        onPressed: () => ref.read(quickPracticeTargetProvider).dismiss(),
      ),
      const SizedBox(width: FluiSpacing.sm),
      FluiButton.outline(
        label: l10n.quickPracticeAnotherAction,
        expand: false,
        onPressed: () =>
            unawaited(ref.read(quickPracticeTargetProvider).another()),
      ),
    ],
  );
}
