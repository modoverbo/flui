import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/plan_today.dart';
import 'package:flui/features/daily/presentation/controllers/time_budget_controller.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_start_target.g.dart';

/// The currently-active chip on HOY's budget-free card, `null` before the
/// user has touched a chip (the card still shows the preselected one —
/// design part-3 §11 U15a). `TodayStartTarget.onActivate` reads this at
/// the moment of the mic gesture, so a duration changed just before
/// tapping the mic is the one that plans the day, never a stale default.
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

/// HOY's own `MicTarget` (design part-3 §11, decision #450.4 —
/// ORCHESTRATOR REVIEW FIX, U15a): the mic on HOY NEVER records directly.
///
/// Its availability is ALWAYS `MicPrepare`, labeled "Empezar la sesión de
/// hoy" (no session yet) or "Continuar la sesión de hoy" (one already
/// exists) — matching `QuickPracticeTarget`'s own established two-phase
/// shape, because `MicController._beginCapture`'s `MicPrepare` branch
/// structurally never proceeds into a capture on the SAME gesture (it
/// `await`s `onActivate()` then returns). `onActivate` plans today's
/// session if one doesn't exist yet (`PlanToday.run`, at whichever
/// duration [TodaySelectedBudgetProvider] currently holds, defaulting to
/// `preselectedBudgetProvider`) and then navigates to
/// `AppRoutes.todayTrain` — it NEVER captures audio itself. Recording the
/// visible challenge is entirely `/today/train`'s own `LoopMicTarget`'s
/// job from that point on; this target does not proxy its prompt,
/// availability, or delivery.
final class TodayStartTarget implements MicTarget {
  new(this._ref) {
    _overviewSubscription = _ref.listen(
      todayOverviewProvider,
      (_, _) => _changes.add(null),
    );
  }

  final Ref _ref;
  final _changes = StreamController<void>.broadcast();
  late final ProviderSubscription<AsyncValue<TodayOverview>>
  _overviewSubscription;

  /// Called once `onActivate` finds or creates today's session — the
  /// widget layer navigates to `AppRoutes.todayTrain` in response.
  /// `MicTarget` has no navigation primitive of its own (documented
  /// deviation, see apply-progress): no other target in `core/mic` has
  /// needed to navigate before this one.
  void Function()? onSessionStarted;

  bool get _hasSession =>
      _ref.read(todayOverviewProvider).value?.session != null;

  @override
  MicPrompt get prompt => MicPrompt(
    actionLabel: _hasSession
        ? 'Continuar la sesión de hoy'
        : 'Empezar la sesión de hoy',
  );

  @override
  Duration get maxDuration => const Duration(seconds: 60);

  @override
  MicAvailability get availability => MicPrepare(prompt.actionLabel, _activate);

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> _activate() async {
    if (!_hasSession) {
      final preselected = await _ref.read(preselectedBudgetProvider.future);
      final selected = _ref.read(todaySelectedBudgetProvider) ?? preselected;
      final result = await _ref.read(planTodayProvider).run(budget: selected);
      if (result case Err()) {
        _ref.read(micControllerProvider)?.emitNotice(MicNotice.planFailed);
        return;
      }
    }
    onSessionStarted?.call();
  }

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async {
    // `MicPrepare` never leads to a capture on THIS target (see the class
    // doc): once a session exists, `/today/train`'s own registered
    // `LoopMicTarget` is what the registry resolves against, so this is
    // unreachable in practice — kept only because `MicTarget.deliver` is
    // a non-optional part of the interface.
    return const MicDeliveryFailed(
      'HOY no graba directamente: abre tu sesión de hoy primero.',
    );
  }

  void disposeTarget() {
    _overviewSubscription.close();
    unawaited(_changes.close());
  }
}

@Riverpod(keepAlive: true)
TodayStartTarget todayStartTarget(Ref ref) {
  final target = TodayStartTarget(ref);
  ref.onDispose(target.disposeTarget);
  return target;
}
