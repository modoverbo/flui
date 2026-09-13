import 'package:meta/meta.dart';

/// Frustration cap: after [maxForcedReveals] forced reveals in one session,
/// stop presenting clozes and switch to reading ("Hoy estás sembrando;
/// mañana cosechas.").
@immutable
final class SessionFrustrationGuard {
  const new({this.forcedReveals = 0});

  static const maxForcedReveals = 3;

  final int forcedReveals;

  bool get isTriggered => forcedReveals >= maxForcedReveals;

  SessionFrustrationGuard recordForcedReveal() =>
      SessionFrustrationGuard(forcedReveals: forcedReveals + 1);
}
