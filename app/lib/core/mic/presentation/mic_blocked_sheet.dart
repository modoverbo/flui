import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the one of the 3 blocked sheets (design §19.6) matching [block]'s
/// own shape — see [MicBlockedSheet].
Future<void> showMicBlockedSheet(
  BuildContext context, {
  required MicBlocked block,
  required MicController controller,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (_) => MicBlockedSheet(block: block, controller: controller),
);

/// The content of a mic-blocked sheet (design §19.6): which of the 3
/// variants renders is derived entirely from [block]'s own shape — never a
/// parallel enum that could drift from `MicController`'s actual latch
/// blocks (design §19.5):
///
/// - no [MicBlockedCta] at all → quota (message only, no retry offered);
/// - a [MicBlockedCta] with a non-null [MicBlockedCta.route] → access
///   (navigates there, e.g. the paywall);
/// - a [MicBlockedCta] with a null [MicBlockedCta.route] → permission
///   (re-requests via [MicController.retryPermission]).
class MicBlockedSheet extends StatelessWidget {
  const new({required this.block, required this.controller, super.key});

  final MicBlocked block;
  final MicController controller;

  @override
  Widget build(BuildContext context) {
    final cta = block.cta;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              block.message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (cta != null) ...[
              const SizedBox(height: FluiSpacing.md),
              FluiButton.primary(
                label: cta.label,
                onPressed: () {
                  Navigator.of(context).maybePop();
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
