import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/plan_today.dart';
import 'package:flui/features/daily/presentation/controllers/time_budget_controller.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/loop_mic_target.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_start_target.g.dart';

/// The currently-active chip on HOY's budget-free card, `null` before the
/// user has touched a chip (the card still shows the preselected one —
/// design part-3 §11 U15a). `TodayStartTarget.deliver` reads this at the
/// moment of the mic gesture, so a duration changed just before tapping
/// the mic is the one that plans the day, never a stale default.
@riverpod
class TodaySelectedBudget extends _$TodaySelectedBudget {
  @override
  TimeBudget? build() => null;

  // Named `select` (not a setter) to match `TimeBudgetController.select`'s
  // own established naming for the same concept on the pre-existing
  // "¿Cuánto tiempo tienes hoy?" screen.
  // ignore: use_setters_to_change_properties
  void select(TimeBudget budget) => state = budget;
}

/// HOY's own `MicTarget` (design part-3 §11, decision #450.4): before
/// today's `daily_sessions` row exists, a single mic gesture both plans
/// and records — `deliver` persists the day's plan (`PlanToday.run`, at
/// whichever duration [TodaySelectedBudgetProvider] currently holds) and
/// THEN forwards the just-captured audio into the loop it just created,
/// equivalent to tapping START, never quick practice (no second
/// activation is required). Once a session exists, this target simply
/// delegates to that day's `LoopMicTarget` for the rest of the loop.
final class TodayStartTarget implements MicTarget {
  new(this._ref);

  final Ref _ref;
  final _changes = StreamController<void>.broadcast();
  LoopRequest? _request;
  ProviderSubscription<LoopMicTarget>? _loopSubscription;

  /// Called once, right after this target's FIRST `deliver` successfully
  /// plans and submits today's session — the widget layer navigates to
  /// `AppRoutes.todayTrain` in response. `MicTarget` has no navigation
  /// primitive of its own (documented deviation, see apply-progress): no
  /// other target in `core/mic` has needed to navigate before this one.
  void Function()? onSessionStarted;

  LoopRequest _requestFor(DailySession session) => LoopRequest(
    context: TrainingContext.daily,
    sessionId: session.localDate.toIso(),
    script: const LoopScript.full(),
    challengeId: session.challengeId,
    targetWordIds: session.wovenWordIds,
  );

  /// `null` while no session exists yet for today. Resolved once from
  /// `todayOverviewProvider`'s current (already-settled) value the first
  /// time something asks — never re-derived from it after this target's
  /// OWN `deliver` just wrote a session, which reads back the value
  /// `PlanToday.run` itself returned instead (a just-written provider can
  /// still serve a stale cached value for a moment — U14c's own learning).
  LoopMicTarget? get _loopTarget {
    final cached = _request;
    if (cached != null) return _ref.read(loopMicTargetProvider(cached));
    final session = _ref.read(todayOverviewProvider).value?.session;
    if (session == null) return null;
    return _attach(session);
  }

  LoopMicTarget _attach(DailySession session) {
    final request = _requestFor(session);
    _request = request;
    _loopSubscription?.close();
    _loopSubscription = _ref.listen(
      loopMicTargetProvider(request),
      (_, _) => _changes.add(null),
    );
    _changes.add(null);
    return _ref.read(loopMicTargetProvider(request));
  }

  @override
  MicPrompt get prompt =>
      _loopTarget?.prompt ??
      const MicPrompt(actionLabel: 'Grabar tu respuesta de hoy');

  @override
  Duration get maxDuration =>
      _loopTarget?.maxDuration ?? const Duration(seconds: 60);

  @override
  MicAvailability get availability =>
      _loopTarget?.availability ?? const MicReady();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    var loop = _loopTarget;
    final startingFresh = loop == null;
    if (loop == null) {
      final preselected = await _ref.read(preselectedBudgetProvider.future);
      final selected = _ref.read(todaySelectedBudgetProvider) ?? preselected;
      final result = await _ref.read(planTodayProvider).run(budget: selected);
      if (result case Err()) {
        return const MicDeliveryFailed(
          'No pudimos preparar tu sesión. Inténtalo de nuevo.',
        );
      }
      loop = _attach((result as Ok<DailySession>).value);
    }
    final delivery = await loop.deliver(audio);
    if (startingFresh) onSessionStarted?.call();
    return delivery;
  }

  void disposeTarget() {
    _loopSubscription?.close();
    unawaited(_changes.close());
  }
}

@Riverpod(keepAlive: true)
TodayStartTarget todayStartTarget(Ref ref) {
  final target = TodayStartTarget(ref);
  ref.onDispose(target.disposeTarget);
  return target;
}
