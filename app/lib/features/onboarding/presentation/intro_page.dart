import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/onboarding/presentation/widgets/micro_lesson_view.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The steps before the account: three benefit pages that make the promise,
/// and one real word so the promise is something the user has already felt.
/// The two preference questions that used to follow the benefits are
/// retired (U14b): the spoken diagnosis replaces them.
enum OnboardingStep { promise, rhythm, ownership, lesson }

class IntroPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage> {
  static const _benefitTransitionDuration = Duration(milliseconds: 220);

  var _index = 0;
  var _lessonDone = false;
  var _movingForward = true;

  List<OnboardingStep> get _steps => OnboardingStep.values;

  OnboardingStep get _step => _steps[_index];

  void _finish() => context.go(AppRoutes.plan);

  void _next() {
    if (_index < 2) return _moveBenefit(forward: true);
    if (_index == _steps.length - 1) return _finish();
    setState(() => _index++);
  }

  void _back() {
    if (_index == 0) return context.go(AppRoutes.welcome);
    if (_index <= 2) return _moveBenefit(forward: false);
    setState(() => _index--);
  }

  void _moveBenefit({required bool forward}) {
    setState(() {
      _movingForward = forward;
      _index += forward ? 1 : -1;
    });
  }

  void _onBenefitSwipe(DragEndDetails details) {
    if (details.primaryVelocity case final velocity?
        when velocity.abs() >= 250) {
      if (velocity < 0 && _index < 2) return _moveBenefit(forward: true);
      if (velocity > 0 && _index > 0) return _moveBenefit(forward: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = _step;
    const onDark = false;

    final body = switch (step) {
      OnboardingStep.promise => _Slide(
        title: l10n.introSlideOneTitle,
        highlight: l10n.introSlideOneHighlight,
        body: l10n.introSlideOneBody,
      ),
      OnboardingStep.rhythm => _Slide(
        title: l10n.introSlideTwoTitle,
        highlight: l10n.introSlideTwoHighlight,
        body: l10n.introSlideTwoBody,
      ),
      OnboardingStep.ownership => _Slide(
        title: l10n.introSlideThreeTitle,
        highlight: l10n.introSlideThreeHighlight,
        body: l10n.introSlideThreeBody,
      ),
      OnboardingStep.lesson => MicroLessonView(
        onResolved: () => setState(() => _lessonDone = true),
      ),
    };

    final canContinue = switch (step) {
      OnboardingStep.lesson => _lessonDone,
      _ => true,
    };

    final pageBody = _index < 3
        ? GestureDetector(
            onHorizontalDragEnd: _onBenefitSwipe,
            child: AnimatedSwitcher(
              duration: FluiMotion.resolve(context, _benefitTransitionDuration),
              switchInCurve: FluiMotion.enter,
              switchOutCurve: FluiMotion.exit,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final previousChild in previousChildren)
                    ExcludeSemantics(child: previousChild),
                  ?currentChild,
                ],
              ),
              transitionBuilder: (child, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  child: child,
                  builder: (context, child) {
                    final direction = _movingForward ? 1.0 : -1.0;
                    final isExiting =
                        animation.status == AnimationStatus.reverse;
                    final offset =
                        (isExiting ? -direction : direction) *
                        (1 - animation.value);
                    return FractionalTranslation(
                      translation: Offset(offset, 0),
                      child: child,
                    );
                  },
                );
              },
              child: KeyedSubtree(key: ValueKey(step), child: body),
            ),
          )
        : body;

    final content = StickyCtaDock(
      dock: _Dock(
        label: step == OnboardingStep.lesson
            ? l10n.onboardingSeePlan
            : l10n.onboardingNext,
        onDark: onDark,
        onPressed: canContinue ? _next : null,
        onSkip: step == OnboardingStep.lesson ? _finish : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Rail(
              index: _index,
              total: _steps.length,
              onDark: onDark,
              onBack: _back,
              onSkip: _finish,
            ),
            Expanded(
              // The step is centred in what is left after the rail and the
              // dock, so a short slide composes instead of leaving a void.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    bottom: StickyCtaDock.reservedHeight,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: StickyCtaDock.contentMinHeight(constraints),
                    ),
                    child: Center(child: PageFrame.column(child: pageBody)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(backgroundColor: FluiColors.cream, body: content);
  }
}

class _Dock extends StatelessWidget {
  const new({
    required this.label,
    required this.onDark,
    required this.onPressed,
    this.onSkip,
  });

  final String label;
  final bool onDark;
  final VoidCallback? onPressed;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final button = onDark
        ? FluiButton.accent(label: label, onPressed: onPressed)
        : FluiButton.primary(label: label, onPressed: onPressed);
    if (onSkip == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: FluiSpacing.xxs),
        FluiButton.text(
          label: context.l10n.onboardingSkipLesson,
          onPressed: onSkip,
          onDark: onDark,
        ),
      ],
    );
  }
}

/// Where you are, what you can leave: a progress rail instead of dots.
class _Rail extends StatelessWidget {
  const new({
    required this.index,
    required this.total,
    required this.onDark,
    required this.onBack,
    required this.onSkip,
  });

  final int index;
  final int total;
  final bool onDark;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FluiSpacing.sm),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.onboardingBack,
              onPressed: onBack,
              icon: Icon(
                LucideIcons.arrow_left,
                color: onDark ? FluiColors.cream : FluiColors.charcoal,
              ),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: FluiProgressBar(
                value: (index + 1) / total,
                semanticLabel: l10n.onboardingStepSemantics(index + 1, total),
                height: 6,
                onDark: onDark,
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            FluiButton.text(
              label: l10n.introSkip,
              onPressed: onSkip,
              onDark: onDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// One promise, on paper, with its key phrase in deep green for contrast.
class _Slide extends StatelessWidget {
  const new({required this.title, required this.highlight, required this.body});

  final String title;
  final String highlight;
  final String body;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final type = layout.type;
    final highlightStart = title.endsWith(highlight) && highlight.isNotEmpty
        ? title.length - highlight.length
        : title.length;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: layout.sectionGap),
      child: RevealLines(
        key: ValueKey(title),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                style: type.displayL.copyWith(color: FluiColors.ink),
                children: [
                  TextSpan(text: title.substring(0, highlightStart)),
                  if (highlightStart < title.length)
                    TextSpan(
                      text: title.substring(highlightStart),
                      style: const TextStyle(color: FluiColors.greenDeep),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: FluiSpacing.lg),
            child: Text(
              body,
              style: type.bodyL.copyWith(color: FluiColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The logo, for the steps that are not a plate.
class OnboardingMark extends StatelessWidget {
  const new({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(borderRadius: FluiRadii.chipAll),
    child: FluiLogo(onDark: onDark, symbolSize: 28),
  );
}
