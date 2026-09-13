import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Labeled text input. Password fields get a show/hide toggle.
class FluiTextField extends StatefulWidget {
  const new({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.isPassword = false,
    this.showPasswordLabel,
    this.hidePasswordLabel,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool isPassword;
  final String? showPasswordLabel;
  final String? hidePasswordLabel;
  final TextCapitalization textCapitalization;

  @override
  State<FluiTextField> createState() => _FluiTextFieldState();
}

class _FluiTextFieldState extends State<FluiTextField> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) {
    final toggleLabel = _obscured
        ? widget.showPasswordLabel
        : widget.hidePasswordLabel;
    // Merged so assistive technologies read the visible label with the field.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: FluiTypography.label.copyWith(color: FluiColors.charcoal),
          ),
          const SizedBox(height: FluiSpacing.xs),
          TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            obscureText: widget.isPassword && _obscured,
            enableSuggestions: !widget.isPassword,
            autocorrect: !widget.isPassword,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            style: FluiTypography.body.copyWith(color: FluiColors.charcoal),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: toggleLabel,
                      icon: Icon(
                        _obscured ? LucideIcons.eye : LucideIcons.eye_off,
                        color: FluiColors.gray,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
