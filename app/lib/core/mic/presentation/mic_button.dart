import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The shell's single mic affordance (design §19.7, D29, D44).
///
/// Owns NO capture logic itself — every gesture is delegated to
/// [controller]: pointer down/up/cancel drive [MicController.pointerDown]/
/// [MicController.pointerUp]/[MicController.pointerCancel] (hold-vs-tap
/// classification lives in `HoldToRecord`, D26); a semantic tap (screen
/// reader "double tap to activate") and Enter/Space (keyboard, switch
/// access) both call [MicController.toggle] directly instead (design D44).
///
/// Never a selected destination: it is always an action, painted the same
/// regardless of which shell branch is current.
class MicButton extends StatefulWidget {
  const new({
    required this.controller,
    this.size = 64,
    this.focusNode,
    super.key,
  });

  final MicController controller;

  /// Visual diameter. The tappable/focusable area is never smaller than
  /// 48 dp (WCAG target size), regardless of [size].
  final double size;

  /// Exposed so a host (or a test) can drive/observe focus explicitly.
  final FocusNode? focusNode;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `MediaQuery.disableAnimationsOf` must not be read in `initState`
    // (its `InheritedWidget` dependency isn't safely establishable there);
    // `didChangeDependencies` runs right after mount and again whenever the
    // reduced-motion setting changes.
    if (FluiMotion.reduced(context)) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _activate() => widget.controller.toggle();

  @override
  Widget build(BuildContext context) {
    final reduced = FluiMotion.reduced(context);
    final diameter = widget.size < 48 ? 48.0 : widget.size;
    return StreamBuilder<MicState>(
      stream: widget.controller.states,
      initialData: widget.controller.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.controller.state;
        final (label, hint, value, recording) = _describe(state);
        return Semantics(
          button: true,
          label: label,
          hint: hint,
          value: value,
          liveRegion: true,
          onTap: _activate,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
                  ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
                  ActivateIntent(),
            },
            child: Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _activate();
                    return null;
                  },
                ),
              },
              child: Focus(
                focusNode: _focusNode,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  // Raw pointer path only (design: "hold is pointer-only").
                  // A physical tap/hold is classified entirely by
                  // `HoldToRecord`'s own down/up timing, never by a
                  // `GestureDetector.onTap` here — that would double-fire
                  // alongside these pointer callbacks for the same gesture.
                  onPointerDown: (_) => widget.controller.pointerDown(),
                  onPointerUp: (_) => widget.controller.pointerUp(),
                  onPointerCancel: (_) => widget.controller.pointerCancel(),
                  child: SizedBox.square(
                    dimension: diameter,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) => _Dot(
                          diameter: diameter,
                          recording: recording,
                          focused: _focused,
                          reduced: reduced,
                          pulseValue: _pulse.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The contextual label/hint/countdown text, from the resolved target's
  /// own prompt (design §19.2) — never a hardcoded "Grabar".
  (String, String?, String?, bool) _describe(MicState state) => switch (state) {
    MicIdle(:final prompt, :final block) => (
      prompt.actionLabel,
      block?.message ?? prompt.hint,
      null,
      false,
    ),
    MicRequestingPermission() => ('Preparando micrófono', null, null, false),
    MicRecording(:final secondsLeft) => (
      'Grabando',
      'Toca para terminar',
      '$secondsLeft',
      true,
    ),
    MicFinishing() => ('Terminando', null, null, false),
    MicDelivering() => ('Analizando tu intento', null, null, false),
  };
}

class _Dot extends StatelessWidget {
  const new({
    required this.diameter,
    required this.recording,
    required this.focused,
    required this.reduced,
    required this.pulseValue,
  });

  final double diameter;
  final bool recording;
  final bool focused;
  final bool reduced;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    // Reduced motion: a static ring instead of the pulsing animation
    // (design §19.7 a11y line).
    final ringScale = reduced ? 1.0 : 1.0 + (pulseValue * 0.12);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (recording && !reduced)
          Transform.scale(
            scale: ringScale,
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: FluiColors.coral.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
          ),
        Container(
          width: diameter * 0.85,
          height: diameter * 0.85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? FluiColors.coral : FluiColors.greenDeep,
            border: focused
                ? Border.all(color: FluiColors.yellowElectric, width: 3)
                : null,
          ),
          child: Center(
            child: recording
                ? const Icon(Icons.stop_rounded, color: FluiColors.cream)
                : const FluiGlyphIcon(
                    FluiGlyph.microphone,
                    size: FluiIconSize.tab,
                    color: FluiColors.cream,
                  ),
          ),
        ),
      ],
    );
  }
}
