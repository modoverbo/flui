import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/widgets/training_loop_view.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// HOY's own speaking loop (`AppRoutes.todayTrain`, U15a, design D41): a
/// branch child of the HOY tab, reached once today's `daily_sessions` row
/// exists (via `PlanToday`, from the chips card's START or the shell mic's
/// `TodayStartTarget`). Hands off entirely to the shared `TrainingLoopView`
/// (`context = daily`, `LoopScript.full()`), the same pattern
/// `TrainingLabModePage` uses for ENTRENAR — this page only resolves
/// today's persisted plan into a `LoopRequest`.
class TodayTrainPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(todayOverviewProvider);
    return Scaffold(
      body: SafeArea(
        child: switch (overview) {
          AsyncValue(hasValue: true, :final value?)
              when value.session != null =>
            TrainingLoopView(
              request: LoopRequest(
                context: TrainingContext.daily,
                sessionId: value.session!.localDate.toIso(),
                script: const LoopScript.full(),
                challengeId: value.session!.challengeId,
                targetWordIds: value.session!.wovenWordIds,
              ),
            ),
          AsyncValue(hasValue: true) || AsyncError() => Center(
            child: EmptyState(
              title: l10n.trainUnavailableTitle,
              message: l10n.trainUnavailableBody,
            ),
          ),
          _ => Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
        },
      ),
    );
  }
}
