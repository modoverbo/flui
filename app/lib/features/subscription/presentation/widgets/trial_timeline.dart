import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// One stop of the trial.
@immutable
final class TrialNode {
  const new({required this.label, required this.body});

  final String label;
  final String body;
}

/// The three dates of the trial, as a vertical timeline whose connector
/// draws itself in yellow.
///
/// The day-5 line only promises a reminder when [FluiFeatures.trialReminder]
/// is on. Until then it says what is true today: the end date is in "Tu
/// progreso". A paywall that promises a notification nobody sends is the
/// dark pattern this product exists without.
class TrialTimeline extends StatelessWidget {
  const new({super.key, this.remindersEnabled = FluiFeatures.trialReminder});

  final bool remindersEnabled;

  static List<TrialNode> nodesOf(
    AppLocalizations l10n, {
    required bool remindersEnabled,
  }) => [
    TrialNode(
      label: l10n.paywallTimelineTodayLabel,
      body: l10n.paywallTimelineTodayBody,
    ),
    TrialNode(
      label: l10n.paywallTimelineMidLabel,
      body: remindersEnabled
          ? l10n.paywallTimelineMidBody
          : l10n.paywallTimelineMidBodyHonest,
    ),
    TrialNode(
      label: l10n.paywallTimelineEndLabel,
      body: l10n.paywallTimelineEndBody,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodes = nodesOf(l10n, remindersEnabled: remindersEnabled);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: 1),
      duration: FluiMotion.resolve(context, FluiMotion.celebration),
      curve: FluiMotion.enter,
      builder: (context, progress, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, node) in nodes.indexed)
            _Node(
              node: node,
              index: index,
              total: nodes.length,
              progress: progress,
            ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const new({
    required this.node,
    required this.index,
    required this.total,
    required this.progress,
  });

  final TrialNode node;
  final int index;
  final int total;
  final double progress;

  static const double _railWidth = 28;
  static const double _dotRadius = 7;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    // Each node owns its slice of the draw.
    final reached = (progress * total - index).clamp(0.0, 1.0);
    final isLast = index == total - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: CustomPaint(
              painter: _RailPainter(
                filled: reached,
                drawTail: !isLast,
                dotRadius: _dotRadius,
              ),
            ),
          ),
          const SizedBox(width: FluiSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : FluiSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    style: type.titleM.copyWith(color: FluiColors.charcoal),
                  ),
                  const SizedBox(height: FluiSpacing.xxs),
                  Text(
                    node.body,
                    style: type.body.copyWith(color: FluiColors.charcoal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const new({
    required this.filled,
    required this.drawTail,
    required this.dotRadius,
  });

  final double filled;
  final bool drawTail;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final top = dotRadius + 4;
    if (drawTail) {
      final line = Paint()
        ..color = FluiColors.greenTint
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, top), Offset(x, size.height), line);
      if (filled > 0) {
        canvas.drawLine(
          Offset(x, top),
          Offset(x, top + (size.height - top) * filled),
          line..color = FluiColors.yellowElectric,
        );
      }
    }
    canvas
      ..drawCircle(
        Offset(x, top),
        dotRadius,
        Paint()
          ..color = filled > 0
              ? FluiColors.yellowElectric
              : FluiColors.greenTint,
      )
      ..drawCircle(
        Offset(x, top),
        dotRadius,
        Paint()
          ..color = FluiColors.greenDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      oldDelegate.filled != filled || oldDelegate.drawTail != drawTail;
}
