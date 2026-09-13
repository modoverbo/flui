import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:material_ui/material_ui.dart';

enum FluiButtonVariant { primary, accent, outline, text }

/// Buttons. Use one [FluiButtonVariant.primary] (or accent on deep green)
/// per screen; everything else is outline or text.
///
/// A primary action is a 14 px rectangle. It is never a pill: a pill floating
/// over a half-empty screen is the shape every subscription app ships, and it
/// reads as a banking app, not as a place where you learn a word.
class FluiButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = FluiButtonVariant.primary,
    this.icon,
    this.glyph,
    this.isLoading = false,
    this.expand = true,
    this.onDark = false,
  });

  const new primary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.glyph,
    this.isLoading = false,
    this.expand = true,
  }) : variant = FluiButtonVariant.primary,
       onDark = false;

  /// Yellow call to action, always with charcoal text.
  const new accent({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.glyph,
    this.isLoading = false,
    this.expand = true,
  }) : variant = FluiButtonVariant.accent,
       onDark = true;

  const new outline({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.glyph,
    this.isLoading = false,
    this.expand = true,
    this.onDark = false,
  }) : variant = FluiButtonVariant.outline;

  const new text({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.glyph,
    this.isLoading = false,
    this.expand = false,
    this.onDark = false,
  }) : variant = FluiButtonVariant.text;

  static const double height = 52;

  final String label;
  final VoidCallback? onPressed;
  final FluiButtonVariant variant;
  final IconData? icon;

  /// A custom glyph instead of a library icon.
  final Widget? glyph;
  final bool isLoading;
  final bool expand;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors();
    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) &&
                background != Colors.transparent
            ? (onDark ? FluiColors.greenSecondary : FluiColors.disabled)
            : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (onDark ? FluiColors.creamMuted : FluiColors.gray)
            : foreground,
      ),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.08)),
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : 0, height),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: FluiSpacing.lg),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: variant == FluiButtonVariant.text
              ? FluiRadii.chipAll
              : FluiRadii.ctaAll,
        ),
      ),
      side: variant == FluiButtonVariant.outline
          ? WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? FluiColors.outline
                    : foreground,
                width: 1.5,
              ),
            )
          : null,
      textStyle: WidgetStatePropertyAll(
        FluiTypeScale.compact.body.copyWith(fontWeight: FontWeight.w600),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );

    final child = isLoading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : _Label(label: label, icon: icon, glyph: glyph);
    final action = onPressed == null ? null : (isLoading ? _ignore : onPressed);

    final button = switch (variant) {
      FluiButtonVariant.primary || FluiButtonVariant.accent => FilledButton(
        onPressed: action,
        style: style,
        child: child,
      ),
      FluiButtonVariant.outline => OutlinedButton(
        onPressed: action,
        style: style,
        child: child,
      ),
      FluiButtonVariant.text => TextButton(
        onPressed: action,
        style: style,
        child: child,
      ),
    };
    return Semantics(
      label: isLoading ? label : null,
      button: true,
      child: button,
    );
  }

  (Color background, Color foreground) _colors() {
    final onSurface = onDark ? FluiColors.cream : FluiColors.greenDeep;
    return switch (variant) {
      FluiButtonVariant.primary => (FluiColors.greenDeep, FluiColors.cream),
      // A yellow surface always carries charcoal, never green.
      FluiButtonVariant.accent => (
        FluiColors.yellowElectric,
        FluiColors.charcoal,
      ),
      FluiButtonVariant.outline ||
      FluiButtonVariant.text => (Colors.transparent, onSurface),
    };
  }

  static void _ignore() {}
}

class _Label extends StatelessWidget {
  const new({required this.label, this.icon, this.glyph});

  final String label;
  final IconData? icon;
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final glyph = this.glyph;
    final text = Text(label, textAlign: TextAlign.center);
    if (icon == null && glyph == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        const SizedBox(width: FluiSpacing.xs),
        ?glyph,
        if (icon != null) Icon(icon, size: 18),
      ],
    );
  }
}
