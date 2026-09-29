import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/presentation/mic_dock.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:material_ui/material_ui.dart';

/// The spoken counterpart of a typed Úsala step's `FluiTextField` + submit
/// button (design §10, D36-D37, U17b): the shell's [MicDock] plus the
/// heard-text display ("Escuché: «...»") and the "Continuar sin hablar"
/// skip action, offered ONLY while the mic is blocked (design D36's own
/// default — access/quota/permission latched, never on a plain mismatch).
/// Shared by `FormRecallView` and `ProductionView`, so this behaviour is
/// defined once, not per view.
class SpokenAnswerControls extends StatelessWidget {
  const new({
    required this.controller,
    required this.heardText,
    required this.onSkip,
    super.key,
  });

  final MicController controller;

  /// The last transcript heard, if any (`FormRecallCheck.lastHeard` or
  /// `ProductionFlow.sentence`) — `null` before the first spoken attempt.
  final String? heardText;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final heard = heardText;
    return StreamBuilder<MicState>(
      stream: controller.states,
      initialData: controller.state,
      builder: (context, snapshot) {
        final micState = snapshot.data;
        final blocked = micState is MicIdle && micState.block != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heard != null) ...[
              Text(
                l10n.spokenUsalaHeard(heard),
                style: context.type.body.copyWith(color: FluiColors.charcoal),
              ),
              const SizedBox(height: FluiSpacing.sm),
            ],
            MicDock(controller: controller),
            if (blocked) ...[
              const SizedBox(height: FluiSpacing.sm),
              Center(
                child: FluiButton.text(
                  label: l10n.spokenUsalaSkip,
                  onPressed: onSkip,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
