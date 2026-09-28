import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flags for promises the product makes before the plumbing exists.
///
/// A paywall may only say what the app can actually do. Each flag here turns
/// on a claim, and stays off until the thing it claims is built.
abstract final class FluiFeatures {
  /// The "Día 5 · Te avisamos" line of the trial timeline.
  ///
  /// While it is off, the timeline shows `paywallTimelineMidBodyHonest`,
  /// which promises only what "Tu progreso" already shows.
  // TODO(flui): flip to `true` together with the day-5 reminder. It needs
  // either push notifications (not wired on web, our first target) or a
  // transactional email from a scheduled Supabase function reading
  // `entitlements.trial_ends_at`.
  static const bool trialReminder = false;

  /// The speaking-gym redesign: the mic-driven ENTRENAR training lab
  /// (U16), and later the shell's raised mic button and every consumer
  /// surface built on top of it (U17-U23e). Off until the engine's last
  /// unit (U20) flips it, per design D17/D32.
  // TODO(flui): flip to `true` in U20, once every gym unit has landed and
  // been verified, alongside deleting this flag and its flag-off branches.
  static const bool speakingGym = false;
}

/// [FluiFeatures.speakingGym], as a provider so a later unit's widget can
/// `ref.watch` it and a test can override it independently of rebuilding
/// [FluiFeatures] itself (design D17: "one const flag + override
/// provider"). No consumer yet — U16 introduces the flag; U23c onward
/// reads it.
final speakingGymEnabledProvider = Provider<bool>(
  (ref) => FluiFeatures.speakingGym,
);
