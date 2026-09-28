import 'package:flui/features/training/domain/challenge.dart';

/// Picks today's quick-practice prompt (design part-3 §7, §19.13; decision
/// #450.3, D33): a published TRAINING challenge unused in the last 7 days,
/// lowest `sortOrder` first. Pure Dart, empty-safe — never throws, and
/// returns `null` rather than falling back to an already-used challenge
/// when nothing else qualifies.
final class QuickPracticePicker {
  const new();

  /// [recentlyUsedChallengeIds] is caller-filtered to whatever window the
  /// caller considers "recent" (design: 7 days) — this method itself does
  /// no date arithmetic.
  Challenge? pick({
    required List<Challenge> publishedChallenges,
    required Set<String> recentlyUsedChallengeIds,
  }) {
    final candidates =
        publishedChallenges
            .where((c) => c.purpose == ChallengePurpose.training)
            .where((c) => !recentlyUsedChallengeIds.contains(c.id))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return candidates.isEmpty ? null : candidates.first;
  }
}
