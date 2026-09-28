import 'dart:async';

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_panel.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_target.dart';
import 'package:material_ui/material_ui.dart';

/// Shows [QuickPracticePanel] as a non-modal overlay card whenever [target]
/// is activated (design §19.13): `QuickPracticeTarget.changes` fires once
/// its first activation resolves a picked challenge (`currentRequest`
/// becomes non-null), and this host reacts by inserting an [OverlayEntry] —
/// the target itself has no `BuildContext` to show UI from directly.
///
/// Deliberately an [OverlayEntry], NOT `showModalBottomSheet`: a modal
/// route's barrier would block hit-testing on the shell's mic underneath
/// it, making the required "second activation records" gesture
/// unreachable while the prompt is showing. The overlay card sits above
/// the shell content but never intercepts touches outside its own bounds,
/// so the mic (and the rest of the screen) stays fully interactive.
///
/// The card stays inserted and rebuilds reactively (via the panel's own
/// `ref.watch` on the training loop) as the loop advances (prompt ->
/// feedback -> summary) and on "Otro reto" (a new request, still
/// non-null) without the entry being torn down and reinserted. It is
/// removed the moment [target] is dismissed ("Cerrar", `currentRequest`
/// becomes null again).
///
/// Entirely absent from the tree while [target] is `null` (flag-off, per
/// `AppShell`'s own guard): mirrors `MicNoticeHost`'s established pattern
/// for a shell-lifetime side-effect widget with zero footprint when the
/// flag is off.
class QuickPracticePanelHost extends StatefulWidget {
  const new({required this.target, required this.child, super.key});

  final QuickPracticeTarget? target;
  final Widget child;

  @override
  State<QuickPracticePanelHost> createState() => _QuickPracticePanelHostState();
}

class _QuickPracticePanelHostState extends State<QuickPracticePanelHost> {
  StreamSubscription<void>? _subscription;
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant QuickPracticePanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      unawaited(_subscription?.cancel());
      _removeEntry();
      _subscribe();
    }
  }

  void _subscribe() {
    final target = widget.target;
    if (target == null) return;
    _subscription = target.changes.listen((_) => _sync(target));
  }

  /// Inserts the overlay entry the first time [target] activates, and
  /// removes it once [target] is dismissed. A loop phase change
  /// (focus -> feedback -> summary) re-renders on its own — the panel
  /// `ref.watch`es the training loop controller directly, independent of
  /// the overlay entry. "Otro reto" (still non-null, but a NEW picked
  /// request) does NOT go through Riverpod, so this explicitly marks the
  /// existing entry dirty to pick up the fresh request/challenge.
  void _sync(QuickPracticeTarget target) {
    if (!mounted) return;
    if (target.currentRequest == null) {
      _removeEntry();
      return;
    }
    final entry = _entry;
    if (entry == null) {
      final newEntry = OverlayEntry(
        builder: (_) => _QuickPracticeOverlayCard(target: target),
      );
      _entry = newEntry;
      Overlay.of(context).insert(newEntry);
    } else {
      entry.markNeedsBuild();
    }
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The overlay card itself: a floating panel anchored above the shell's
/// bottom bar/mic, non-modal (no barrier — [Positioned] inside the plain
/// [Overlay], not a route).
class _QuickPracticeOverlayCard extends StatelessWidget {
  const new({required this.target});

  final QuickPracticeTarget target;

  @override
  Widget build(BuildContext context) => Positioned(
    left: FluiSpacing.lg,
    right: FluiSpacing.lg,
    bottom: 110,
    child: Material(
      color: FluiColors.surface,
      elevation: 8,
      borderRadius: FluiRadii.cardAll,
      child: Padding(
        padding: const EdgeInsets.all(FluiSpacing.lg),
        child: QuickPracticePanel(
          request: target.currentRequest!,
          challenge: target.currentChallenge,
        ),
      ),
    ),
  );
}
