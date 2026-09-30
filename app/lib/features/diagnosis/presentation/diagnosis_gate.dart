import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnosis_gate.g.dart';

/// What the router knows about the signed-in user's mandatory diagnosis
/// (design part-3 §11, D16): a pure gate, table-testable exactly like
/// `AccessGate`/`DailyGate`.
enum DiagnosisGate {
  /// A neutral default for tests unrelated to diagnosis; never produced by
  /// [diagnosisGateProvider] itself.
  notRequired,

  /// No profile exists yet for this user: every screen
  /// except the diagnosis routes themselves redirects here.
  required,

  /// A profile already exists; the diagnosis routes are only reachable
  /// again through an explicit retake (`?retake=1`, U14c).
  completed,

  /// The profile lookup failed (offline, etc). The splash offers a retry,
  /// exactly like `AccessGate.error`.
  error,

  /// Still loading, or the signed-in user id is not known yet.
  unknown,
}

@Riverpod(keepAlive: true)
DiagnosisGate diagnosisGate(Ref ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return DiagnosisGate.unknown;
  return switch (ref.watch(latestSkillProfileProvider(userId))) {
    AsyncValue(hasValue: true, :final value) =>
      value == null ? DiagnosisGate.required : DiagnosisGate.completed,
    AsyncError() => DiagnosisGate.error,
    _ => DiagnosisGate.unknown,
  };
}
