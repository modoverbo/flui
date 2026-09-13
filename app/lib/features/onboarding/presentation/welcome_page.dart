import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class WelcomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomeView(
      onStart: () => context.go(AppRoutes.intro),
      onSignIn: () => context.go(AppRoutes.login),
    );
  }
}

class WelcomeView extends StatelessWidget {
  const new({required this.onStart, required this.onSignIn, super.key});

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: FluiColors.greenDeep,
      body: Stack(
        children: [
          // Large, quiet wave graphic instead of stock imagery.
          const Positioned(
            top: -40,
            right: -90,
            child: ExcludeSemantics(
              child: FluiSymbol(size: 340, color: FluiColors.greenSecondary),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: FluiSpacing.contentMaxWidth,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(FluiSpacing.lg),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - FluiSpacing.lg * 2,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: FluiLogo(onDark: true),
                            ),
                            const Spacer(),
                            const SizedBox(height: FluiSpacing.xxl),
                            _Tagline(
                              text: l10n.welcomeTagline,
                              highlight: l10n.welcomeTaglineHighlight,
                            ),
                            const SizedBox(height: FluiSpacing.xxl),
                            FluiButton.accent(
                              label: l10n.welcomeStart,
                              onPressed: onStart,
                            ),
                            const SizedBox(height: FluiSpacing.xs),
                            Center(
                              child: FluiButton.text(
                                label: l10n.welcomeHaveAccount,
                                onPressed: onSignIn,
                                onDark: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const new({required this.text, required this.highlight});

  final String text;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final style = FluiTypography.featuredWord.copyWith(color: FluiColors.cream);
    final split = text.endsWith(highlight)
        ? text.length - highlight.length
        : text.length;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: text.substring(0, split)),
            if (split < text.length)
              TextSpan(
                text: text.substring(split),
                style: const TextStyle(color: FluiColors.yellowElectric),
              ),
          ],
        ),
      ),
    );
  }
}
