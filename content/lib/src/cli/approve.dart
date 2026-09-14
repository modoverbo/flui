/// Promotion of `gated` words to `approved`.
///
/// There is deliberately **no human sign-off step** between the two. Content
/// is written by agents and reviewed by agents; a founder clicking "approve"
/// on a word two blind reviewers already answered correctly adds a delay, not
/// a check. What replaces it is production telemetry — see `content/GATE.md`.
///
/// The promotion is still an explicit command rather than something the gate
/// does on its own, because "this word is now live" deserves a line in the
/// shell history.
library;

import 'package:content/src/model/word.dart';

/// What `content:approve` would do to the catalog.
final class Promotion {
  const Promotion({required this.promoted, required this.skipped});

  /// Slugs whose status becomes `approved`, sorted.
  final List<String> promoted;

  /// Slug to the reason it stays where it is.
  final Map<String, String> skipped;
}

/// Plans the `gated` → `approved` promotion over [statusBySlug].
///
/// Only `gated` moves: a `draft` or `validated` word has not been through the
/// adversarial gate, and an `approved` one is already there.
Promotion planPromotion(
  Map<String, String> statusBySlug, {
  String? onlySlug,
}) {
  final promoted = <String>[];
  final skipped = <String, String>{};
  final slugs = statusBySlug.keys.toList()..sort();

  for (final slug in slugs) {
    if (onlySlug != null && slug != onlySlug) continue;
    final status = statusBySlug[slug]!;
    if (status == WordStatus.gated.name) {
      promoted.add(slug);
      continue;
    }
    skipped[slug] = status == WordStatus.approved.name
        ? 'already approved'
        : 'status is "$status", not "${WordStatus.gated.name}" — only a word '
              'both gate passes answered correctly can be promoted';
  }
  return Promotion(promoted: promoted, skipped: skipped);
}
