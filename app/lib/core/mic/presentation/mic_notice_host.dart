import 'dart:async';

import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a dismissible, distinct-copy notice (design §19.6, D43) whenever
/// [controller]'s `notices` stream emits — a one-shot explanation, never a
/// persistent `MicIdle.block` sheet (see `MicBlockedSheet`). Wraps the
/// signed-in shell so a cancellation/too-short/permission notice surfaces
/// regardless of which tab is active when it fires.
///
/// [controller] is nullable (mirrors `MicButton`/`FluiBottomBar`): null
/// only for the brief instant around sign-out/sign-in — the host then
/// shows nothing but still renders [child].
class MicNoticeHost extends StatefulWidget {
  const new({required this.controller, required this.child, super.key});

  final MicController? controller;
  final Widget child;

  @override
  State<MicNoticeHost> createState() => _MicNoticeHostState();
}

class _MicNoticeHostState extends State<MicNoticeHost> {
  StreamSubscription<MicNotice>? _subscription;
  MicController? _subscribedTo;

  void _syncSubscription() {
    final controller = widget.controller;
    if (identical(controller, _subscribedTo)) return;
    _subscribedTo = controller;
    unawaited(_subscription?.cancel());
    _subscription = controller?.notices.listen(_show);
  }

  void _show(MicNotice notice) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_copyFor(notice)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void didUpdateWidget(covariant MicNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSubscription();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncSubscription();
    return widget.child;
  }
}

/// The distinct copy per code (design D43). `cancelledByNavigation`,
/// `cancelledByBackground`, and `tooShort` use the design's own normative
/// wording verbatim; `permissionDenied`/`busy`/`deliveryFailed`/
/// `planFailed` follow the same neutral, "tú" voice.
String _copyFor(MicNotice notice) => switch (notice) {
  MicNotice.cancelledByNavigation =>
    'Grabación cancelada: cambiaste de pantalla.',
  MicNotice.cancelledByBackground =>
    'Grabación cancelada: la app pasó a segundo plano.',
  MicNotice.tooShort =>
    'Fue muy corto y no lo enviamos. Mantén pulsado mientras hablas, o '
        'toca una vez para empezar y otra para terminar.',
  MicNotice.permissionDenied =>
    'No pudimos grabar: activa el micrófono en los ajustes y vuelve a '
        'intentarlo.',
  MicNotice.busy =>
    'Ya estamos analizando tu intento anterior. Espera un '
        'momento.',
  MicNotice.deliveryFailed =>
    'No pudimos enviar tu grabación. Vuelve a intentarlo.',
  MicNotice.planFailed =>
    'No pudimos preparar tu sesión de hoy. Inténtalo de nuevo.',
  MicNotice.noSpeech => noSpeechDeliveryMessage,
};
