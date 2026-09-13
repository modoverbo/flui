import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/content_column.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Three short, skippable slides before creating the account.
class IntroPage extends StatefulWidget {
  const new({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.go(AppRoutes.register);

  void _next(int count) {
    if (_index == count - 1) return _finish();
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = [
      (
        LucideIcons.message_square_quote,
        l10n.introSlideOneTitle,
        l10n.introSlideOneBody,
      ),
      (LucideIcons.timer, l10n.introSlideTwoTitle, l10n.introSlideTwoBody),
      (
        LucideIcons.sparkles,
        l10n.introSlideThreeTitle,
        l10n.introSlideThreeBody,
      ),
    ];
    final isLast = _index == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: ContentColumn(
          child: Column(
            children: [
              const SizedBox(height: FluiSpacing.md),
              Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: FluiLogo(symbolSize: 28),
                      ),
                    ),
                  ),
                  FluiButton.text(label: l10n.introSkip, onPressed: _finish),
                ],
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) => setState(() => _index = index),
                  children: [
                    for (final (i, (icon, title, body)) in slides.indexed)
                      _Slide(
                        icon: icon,
                        title: title,
                        body: body,
                        label: l10n.introSlideLabel(i + 1, slides.length),
                      ),
                  ],
                ),
              ),
              _Dots(count: slides.length, index: _index),
              const SizedBox(height: FluiSpacing.lg),
              FluiButton.primary(
                label: isLast ? l10n.introCreateAccount : l10n.introNext,
                onPressed: () => _next(slides.length),
              ),
              const SizedBox(height: FluiSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.label,
  });

  final IconData icon;
  final String title;
  final String body;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: FluiSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: FluiColors.greenTint,
                borderRadius: FluiRadii.xlAll,
              ),
              child: Padding(
                padding: const EdgeInsets.all(FluiSpacing.lg),
                child: Icon(icon, size: 40, color: FluiColors.greenDeep),
              ),
            ),
            const SizedBox(height: FluiSpacing.xl),
            Text(
              title,
              style: FluiTypography.h1.copyWith(color: FluiColors.charcoal),
            ),
            const SizedBox(height: FluiSpacing.md),
            Text(
              body,
              style: FluiTypography.body.copyWith(color: FluiColors.gray),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const new({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? FluiColors.greenDeep : FluiColors.outline,
                borderRadius: FluiRadii.pill,
              ),
            ),
        ],
      ),
    );
  }
}
