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
}
