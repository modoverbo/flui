import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// A docked mic affordance for root-navigator screens that live outside
/// the shell's bottom bar/rail — diagnosis, `/session`'s spoken steps
/// (design D30). The shell's single [MicButton] is still the only capture
/// trigger (decision #448); this only makes it visible/operable on a
/// screen where the shell chrome itself is absent, alongside a passive
/// status panel reflecting [MicController.states] — never a second
/// record affordance or any capture logic of its own.
class MicDock extends StatelessWidget {
  const new({required this.controller, super.key});

  final MicController controller;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _MicDockStatus(controller: controller),
      const SizedBox(height: FluiSpacing.md),
      MicButton(controller: controller),
    ],
  );
}

class _MicDockStatus extends StatelessWidget {
  const new({required this.controller});

  final MicController controller;

  @override
  Widget build(BuildContext context) => StreamBuilder<MicState>(
    stream: controller.states,
    initialData: controller.state,
    builder: (context, snapshot) {
      final state = snapshot.data ?? controller.state;
      if (state case MicIdle(:final block?)) {
        return _MicDockBlocked(block: block, controller: controller);
      }
      return Semantics(
        liveRegion: true,
        label: _labelFor(state),
        child: Text(_labelFor(state), textAlign: TextAlign.center),
      );
    },
  );

  String _labelFor(MicState state) => switch (state) {
    MicIdle(:final prompt) => prompt.actionLabel,
    MicRequestingPermission() => 'Preparando micrófono',
    MicRecording(:final secondsLeft) => 'Grabando · ${secondsLeft}s',
    MicFinishing() => 'Terminando',
    MicDelivering() => 'Analizando tu intento',
  };
}

/// The message/CTA for a controller-level latch (access/quota/permission) —
/// the same generic rendering `TrainingLoopView`'s own status panel uses
/// (design §19.5): the shape alone (message + optional CTA) decides what
/// renders, never a parallel enum.
class _MicDockBlocked extends StatelessWidget {
  const new({required this.block, required this.controller});

  final MicBlocked block;
  final MicController controller;

  @override
  Widget build(BuildContext context) {
    final cta = block.cta;
    return Semantics(
      liveRegion: true,
      label: block.message,
      child: FluiCard(
        color: FluiColors.yellowTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              block.message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (cta != null) ...[
              const SizedBox(height: FluiSpacing.sm),
              FluiButton.outline(
                label: cta.label,
                onPressed: () {
                  final route = cta.route;
                  if (route != null) {
                    context.go(route);
                  } else {
                    controller.retryPermission();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
