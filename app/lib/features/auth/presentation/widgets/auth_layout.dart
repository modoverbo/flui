import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:material_ui/material_ui.dart';

/// Shared layout of the auth screens: logo, title, subtitle, form.
class AuthLayout extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: FluiSpacing.lg),
          child: ContentColumn(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FluiLogo(symbolSize: 32),
                  ),
                  const SizedBox(height: FluiSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: FluiTypography.h1.copyWith(
                        color: FluiColors.charcoal,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: FluiSpacing.xs),
                    Text(
                      subtitle,
                      style: FluiTypography.body.copyWith(
                        color: FluiColors.gray,
                      ),
                    ),
                  ],
                  const SizedBox(height: FluiSpacing.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
