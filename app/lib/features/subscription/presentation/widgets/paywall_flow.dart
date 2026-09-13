import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/presentation/widgets/onboarding_questions.dart';
import 'package:flui/features/reading/presentation/scene_label.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/features/subscription/presentation/widgets/plan_card.dart';
import 'package:flui/features/subscription/presentation/widgets/trial_timeline.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// The three pages of the paywall. Splitting the decision converts better
/// than one long page (Superwall, 2026: 12.41 % vs 9.07 %), and it lets each
/// page answer one question: what do I get, what happens when, what do I
/// pay.
enum PaywallStep { plan, trial, choose }

/// Why the paywall is on screen.
enum PaywallMode {
  /// Before the account exists: the last step creates it.
  preview,

  /// After signing in: the last step opens the checkout.
  checkout,
}

class PaywallFlow extends StatefulWidget {
  const new({
    required this.mode,
    required this.plans,
    required this.selectedPlanId,
    required this.onSelected,
    required this.onFinish,
    super.key,
    this.name,
    this.answers = OnboardingAnswers.empty,
    this.initialStep = PaywallStep.plan,
    this.isBusy = false,
    this.header,
    this.footer,
  });

  final PaywallMode mode;
  final List<SubscriptionPlan> plans;
  final String? selectedPlanId;
  final ValueChanged<String> onSelected;

  /// Runs with the selected plan id on the last step.
  final ValueChanged<String> onFinish;
  final String? name;
  final OnboardingAnswers answers;
  final PaywallStep initialStep;
  final bool isBusy;

  /// Sits above the pages (the logo, a sign-out action).
  final Widget? header;

  /// Sits under the call to action (errors, status lines).
  final Widget? footer;

  @override
  State<PaywallFlow> createState() => _PaywallFlowState();
}

class _PaywallFlowState extends State<PaywallFlow> {
  late int _index = widget.initialStep.index;

  PaywallStep get _step => PaywallStep.values[_index];

  void _next(String? planId) {
    if (_step == PaywallStep.choose) {
      if (planId != null) widget.onFinish(planId);
      return;
    }
    setState(() => _index++);
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final selected = widget.selectedPlanId ?? recommendedPlanId(widget.plans);
    final step = _step;

    final ctaLabel = switch ((step, widget.mode)) {
      (PaywallStep.choose, PaywallMode.preview) => l10n.paywallCreateAccount,
      (PaywallStep.choose, PaywallMode.checkout) => l10n.paywallCta,
      _ => l10n.paywallNext,
    };

    return StickyCtaDock(
      dock: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FluiButton.accent(
            label: ctaLabel,
            isLoading: widget.isBusy,
            onPressed: step == PaywallStep.choose && selected == null
                ? null
                : () => _next(selected),
          ),
          const SizedBox(height: FluiSpacing.xs),
          Text(
            step == PaywallStep.choose && widget.mode == PaywallMode.preview
                ? l10n.paywallPreviewNote
                : l10n.paywallTodayFree,
            textAlign: TextAlign.center,
            style: context.type.body.copyWith(color: FluiColors.gray),
          ),
          ?widget.footer,
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Rail(index: _index, onBack: _index == 0 ? null : _back),
            ?widget.header,
            Expanded(
              // A short page is centred in what is left after the rail and
              // the dock, so page 2 never ends in half a screen of nothing.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    bottom: StickyCtaDock.reservedHeight,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - StickyCtaDock.reservedHeight,
                    ),
                    child: Center(
                      child: PageFrame.column(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: layout.blockGap),
                          child: switch (step) {
                            PaywallStep.plan => _PlanPage(
                              name: widget.name,
                              answers: widget.answers,
                            ),
                            PaywallStep.trial => const _TrialPage(),
                            PaywallStep.choose => _ChoosePage(
                              plans: widget.plans,
                              selectedPlanId: selected,
                              onSelected: widget.onSelected,
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const new({required this.index, required this.onBack});

  final int index;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const total = 3;
    return PageFrame.column(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FluiSpacing.sm),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.paywallBack,
              onPressed: onBack,
              icon: const Icon(LucideIcons.arrow_left),
            ),
            const SizedBox(width: FluiSpacing.xs),
            Expanded(
              child: FluiProgressBar(
                value: (index + 1) / total,
                semanticLabel: l10n.paywallStepSemantics(index + 1, total),
                height: 6,
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            FluiLabel(switch (PaywallStep.values[index]) {
              PaywallStep.plan => l10n.paywallStepPlan,
              PaywallStep.trial => l10n.paywallStepTrial,
              PaywallStep.choose => l10n.paywallStepChoose,
            }),
          ],
        ),
      ),
    );
  }
}

/// Page 1: the plan, in the user's own words.
class _PlanPage extends StatelessWidget {
  const new({required this.name, required this.answers});

  final String? name;
  final OnboardingAnswers answers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;
    final trimmed = name?.trim();
    final contexts = joinContexts([
      for (final scene in answers.orderedContexts)
        sceneLabel(l10n, scene).toLowerCase(),
    ]);
    final tone = answers.tone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: layout.blockGap),
        FluiPlate(
          padding: EdgeInsets.all(
            layout.isWide ? FluiSpacing.xl : FluiSpacing.ml,
          ),
          child: RevealLines(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  trimmed == null || trimmed.isEmpty
                      ? l10n.paywallPlanReadyAnonymous
                      : l10n.paywallPlanReady(trimmed),
                  style: type.displayL.copyWith(color: FluiColors.cream),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: layout.blockGap),
        // Three lines, each one an answer the user gave us. No invented
        // "join 12,000 learners": we do not have that number.
        _CheckRow(
          glyph: FluiGlyph.inContext,
          text: contexts.isEmpty
              ? l10n.paywallPlanContextsAny
              : l10n.paywallPlanContexts(contexts),
        ),
        _CheckRow(
          glyph: FluiGlyph.register,
          text: tone == null
              ? l10n.paywallPlanToneAny
              : l10n.paywallPlanTone(
                  ToneQuestion.labelsOf(l10n, tone).$1.toLowerCase(),
                ),
        ),
        _CheckRow(glyph: FluiGlyph.wordOfTheDay, text: l10n.paywallPlanRhythm),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const new({required this.glyph, required this.text});

  final FluiGlyph glyph;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FluiSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FluiGlyphIcon(glyph, color: FluiColors.greenSecondary),
          ),
          const SizedBox(width: FluiSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.type.bodyL.copyWith(color: FluiColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 2: what happens, and when.
class _TrialPage extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: layout.blockGap),
        Semantics(
          header: true,
          child: Text(
            l10n.paywallTimelineTitle,
            style: type.titleL.copyWith(color: FluiColors.charcoal),
          ),
        ),
        SizedBox(height: layout.blockGap),
        const TrialTimeline(),
        SizedBox(height: layout.blockGap),
        Text(
          l10n.paywallTrialSafety,
          style: type.bodyL.copyWith(
            color: FluiColors.greenDeep,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Page 3: the decision.
class _ChoosePage extends StatelessWidget {
  const new({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelected,
  });

  final List<SubscriptionPlan> plans;
  final String? selectedPlanId;
  final ValueChanged<String> onSelected;

  /// Recommended first and dominant, the rest after it.
  static List<SubscriptionPlan> ordered(List<SubscriptionPlan> plans) {
    final recommended = recommendedPlanId(plans);
    return [
      for (final plan in plans)
        if (plan.id == recommended) plan,
      for (final plan in plans)
        if (plan.id != recommended) plan,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;
    final recommended = recommendedPlanId(plans);
    // One glyph per promise, not the same medal five times.
    final benefits = [
      (FluiGlyph.wordOfTheDay, l10n.paywallBenefitOne),
      (FluiGlyph.inContext, l10n.paywallBenefitTwo),
      (FluiGlyph.microphone, l10n.paywallBenefitThree),
      (FluiGlyph.review, l10n.paywallBenefitFour),
      (FluiGlyph.onda, l10n.paywallBenefitFive),
    ];
    final objections = [
      (l10n.paywallObjectionTimeQuestion, l10n.paywallObjectionTimeAnswer),
      (
        l10n.paywallObjectionSpanishQuestion,
        l10n.paywallObjectionSpanishAnswer,
      ),
      (l10n.paywallObjectionCancelQuestion, l10n.paywallObjectionCancelAnswer),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: layout.blockGap),
        Semantics(
          header: true,
          child: Text(
            l10n.paywallChooseTitle,
            style: type.titleL.copyWith(color: FluiColors.charcoal),
          ),
        ),
        SizedBox(height: layout.blockGap),
        for (final plan in ordered(plans)) ...[
          PlanCard(
            plan: plan,
            selected: plan.id == selectedPlanId,
            recommended: plan.id == recommended,
            onSelected: () => onSelected(plan.id),
          ),
          const SizedBox(height: FluiSpacing.sm),
        ],
        SizedBox(height: layout.blockGap),
        SectionHeader(
          title: l10n.paywallIncludesTitle,
          glyph: const FluiGlyphIcon(FluiGlyph.achievement),
        ),
        for (final (glyph, benefit) in benefits)
          _CheckRow(glyph: glyph, text: benefit),
        SizedBox(height: layout.blockGap),
        SectionHeader(
          title: l10n.paywallObjectionsTitle,
          glyph: const FluiGlyphIcon(FluiGlyph.register),
        ),
        for (final (question, answer) in objections) ...[
          ExpandableChip(question: question, answer: answer),
          const SizedBox(height: FluiSpacing.xs),
        ],
      ],
    );
  }
}
