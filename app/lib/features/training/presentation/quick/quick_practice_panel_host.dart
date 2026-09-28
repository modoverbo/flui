import 'dart:async';

import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_panel.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_target.dart';
import 'package:material_ui/material_ui.dart';

/// Shows [QuickPracticePanel] as a modal sheet whenever [target] is
/// activated (design §19.13): `QuickPracticeTarget.changes` fires once its
/// first activation resolves a picked challenge (`currentRequest` becomes
/// non-null), and this host reacts by opening the sheet — the target
/// itself has no `BuildContext` to show UI from directly.
///
/// The sheet stays open and rebuilds reactively as the shared training
/// loop advances (prompt -> feedback -> summary) without being reopened,
/// and closes itself the moment [target] is dismissed (`currentRequest`
/// becomes null again — "Cerrar", or a fresh [QuickPracticeTarget.another]
/// never triggers this since `currentRequest` stays non-null across it).
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
  bool _sheetOpen = false;

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
      _subscribe();
    }
  }

  void _subscribe() {
    final target = widget.target;
    if (target == null) return;
    _subscription = target.changes.listen((_) => _maybeShowSheet(target));
  }

  void _maybeShowSheet(QuickPracticeTarget target) {
    if (target.currentRequest == null || _sheetOpen || !mounted) return;
    _sheetOpen = true;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(FluiSpacing.lg),
          child: _QuickPracticeSheetBody(target: target),
        ),
      ).whenComplete(() => _sheetOpen = false),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reactively renders [QuickPracticePanel] for whatever [target] currently
/// resolves, and pops itself once [target] is dismissed — a single
/// `StreamBuilder` avoids the host needing to reopen the sheet on "Otro
/// reto" (the request identity changes, but `currentRequest` stays
/// non-null throughout).
class _QuickPracticeSheetBody extends StatelessWidget {
  const new({required this.target});

  final QuickPracticeTarget target;

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: target.changes,
    builder: (context, _) {
      final request = target.currentRequest;
      if (request == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        return const SizedBox.shrink();
      }
      return QuickPracticePanel(
        request: request,
        challenge: target.currentChallenge,
      );
    },
  );
}
