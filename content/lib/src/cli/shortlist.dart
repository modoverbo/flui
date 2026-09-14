import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/corpus/metrics.dart';
import 'package:content/src/model/word.dart';
import 'package:content/src/text/spanish_text.dart';

/// Candidates for one theme that the existing library leaves room for.
final class ShortlistResult {
  const ShortlistResult({
    required this.theme,
    required this.accepted,
    required this.rejected,
    required this.considered,
  });

  final String theme;
  final List<CandidateRow> accepted;

  /// Lemma to the reason it cannot be authored next.
  final Map<String, String> rejected;

  /// How many rows carried the theme before filtering.
  final int considered;

  Map<String, Object?> toJson() => {
    'theme': theme,
    'considered': considered,
    'accepted': [for (final row in accepted) row.toJson()],
    'rejected': rejected,
  };

  String format() {
    final buffer = StringBuffer()
      ..writeln(
        'theme $theme — $considered candidates carry it, '
        '${accepted.length} are free to author',
      )
      ..writeln();
    if (accepted.isEmpty) {
      buffer.writeln('  (nothing available)');
    }
    for (final row in accepted) {
      buffer.writeln(
        '  ${row.lemma.padRight(20)} ${row.pos.padRight(11)} '
        'zipf ${row.zipf.toStringAsFixed(2)}  dp ${row.dp.toStringAsFixed(2)}  '
        'comodín ${row.comodinLeverage.toStringAsFixed(2)}  '
        'score ${row.score.toStringAsFixed(3)}',
      );
    }
    if (rejected.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('blocked by the current library:');
      final lemmas = rejected.keys.toList()..sort();
      for (final lemma in lemmas) {
        buffer.writeln('  ${lemma.padRight(20)} ${rejected[lemma]}');
      }
    }
    return buffer.toString();
  }
}

/// Distance at which two lemmas are close enough to interfere (§7).
const paronymDistance = 2;

/// Filters the pool for one theme against everything the library already has.
///
/// The four exclusions mirror the rules the catalog validators enforce, so a
/// word taken from this list cannot collide with the library later:
/// duplicate lemma, family member, paronym clash, semantic-set clash.
ShortlistResult shortlistFor({
  required String theme,
  required List<CandidateRow> candidates,
  required List<Word> library,
  int limit = 20,
}) {
  final existingLemmas = <String, String>{
    for (final word in library) foldForComparison(word.lemma): word.slug,
  };
  final familyMembers = <String, String>{
    for (final word in library)
      for (final member in word.family) foldForComparison(member): word.slug,
  };
  final confusionTargets = <String, String>{
    for (final word in library)
      for (final confusion in word.confusions)
        foldForComparison(confusion.confusedWith): word.slug,
  };
  final semanticSets = <String, String>{
    for (final word in library) stem(word.lemma, 5): word.slug,
  };

  final carrying =
      [
        for (final row in candidates)
          if (row.suggestedThemes.contains(theme)) row,
      ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.lemma.compareTo(b.lemma);
      });

  final accepted = <CandidateRow>[];
  final rejected = <String, String>{};
  for (final row in carrying) {
    if (accepted.length >= limit) break;
    final folded = foldForComparison(row.lemma);

    final owner = existingLemmas[folded];
    if (owner != null) {
      rejected[row.lemma] = 'already in the library as $owner';
      continue;
    }
    final family = familyMembers[folded];
    if (family != null) {
      rejected[row.lemma] = 'family member of $family';
      continue;
    }
    final confusion = confusionTargets[folded];
    if (confusion != null) {
      rejected[row.lemma] = 'named by a confusion of $confusion';
      continue;
    }
    final paronym = _paronymOf(folded, existingLemmas.keys);
    if (paronym != null) {
      rejected[row.lemma] =
          'paronym of ${existingLemmas[paronym]} ($paronym), which the '
          'interference rule keeps apart';
      continue;
    }
    final set = semanticSets[stem(row.lemma, 5)];
    if (set != null) {
      rejected[row.lemma] = 'semantic set of $set';
      continue;
    }
    accepted.add(row);
  }

  return ShortlistResult(
    theme: theme,
    accepted: accepted,
    rejected: rejected,
    considered: carrying.length,
  );
}

String? _paronymOf(String lemma, Iterable<String> existing) {
  for (final other in existing) {
    if ((other.length - lemma.length).abs() > 1) continue;
    if (editDistance(lemma, other) <= paronymDistance) return other;
  }
  return null;
}
