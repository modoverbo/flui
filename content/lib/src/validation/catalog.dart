import 'package:content/src/model/catalogue.dart';
import 'package:content/src/model/word.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/validator.dart';

Issue _issue(
  ContentValidator validator,
  String slug,
  String location,
  String message,
) => Issue(
  code: validator.code,
  severity: validator.severity,
  slug: slug,
  location: location,
  message: message,
);

/// A lemma may appear once in the catalog, and never as another word's family
/// member: the session planner and the mastery model both key on the lemma.
final class DuplicateLemmaValidator extends LibraryValidator {
  const DuplicateLemmaValidator();

  @override
  String get code => 'duplicate_lemma';

  @override
  String get description =>
      'every lemma is unique across the library and across every family array';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateLibrary(LibraryContext context) {
    final issues = <Issue>[];
    final lemmaOwners = <String, List<String>>{};
    for (final word in context.words) {
      lemmaOwners
          .putIfAbsent(foldForComparison(word.lemma), () => [])
          .add(word.slug);
    }
    for (final entry in lemmaOwners.entries) {
      if (entry.value.length > 1) {
        issues.add(
          _issue(
            this,
            entry.value.first,
            'lemma',
            'lemma "${entry.key}" is used by ${entry.value.join(', ')}',
          ),
        );
      }
    }

    final familyOwners = <String, List<String>>{};
    for (final word in context.words) {
      for (final member in word.family) {
        familyOwners
            .putIfAbsent(foldForComparison(member), () => [])
            .add(word.slug);
      }
    }
    for (final entry in familyOwners.entries) {
      if (entry.value.length > 1) {
        issues.add(
          _issue(
            this,
            entry.value.first,
            'family',
            'family member "${entry.key}" is claimed by ${entry.value.join(', ')}',
          ),
        );
      }
      final owner = lemmaOwners[entry.key];
      if (owner != null) {
        final foreign = entry.value
            .where((slug) => !owner.contains(slug))
            .toList();
        if (foreign.isNotEmpty) {
          issues.add(
            _issue(
              this,
              foreign.first,
              'family',
              '"${entry.key}" is the lemma of ${owner.join(', ')} and also a family '
                  'member of ${foreign.join(', ')}',
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// Themes must exist in content/themes.yml, be 1..3, unique, relevance 1..3.
final class ThemeTaxonomyValidator extends WordValidator {
  const ThemeTaxonomyValidator();

  @override
  String get code => 'themes';

  @override
  String get description =>
      '1..3 themes, each from content/themes.yml, unique, relevance 1..3';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    if (word.themes.isEmpty || word.themes.length > 3) {
      issues.add(
        _issue(
          this,
          word.slug,
          'themes',
          'expected 1..3 themes, found ${word.themes.length}',
        ),
      );
    }
    final seen = <String>{};
    for (final theme in word.themes) {
      if (context.taxonomy.bySlug(theme.slug) == null) {
        issues.add(
          _issue(this, word.slug, 'themes', 'unknown theme "${theme.slug}"'),
        );
      }
      if (!seen.add(theme.slug)) {
        issues.add(
          _issue(
            this,
            word.slug,
            'themes',
            'theme "${theme.slug}" is repeated',
          ),
        );
      }
      if (theme.relevance < 1 || theme.relevance > 3) {
        issues.add(
          _issue(
            this,
            word.slug,
            'themes',
            'relevance ${theme.relevance} for "${theme.slug}" is outside 1..3',
          ),
        );
      }
    }
    return issues;
  }
}

/// A confusion between two catalog words is declared by both of them.
///
/// The interference rule of learning-method §7 is declaration-driven, not
/// heuristic: two words are confusable because a file says so. [areConfusable]
/// and the app's rule both accept either direction, which is exactly what makes
/// a one-sided declaration invisible — the pair works until the one file that
/// carries it is edited, and then the protection disappears with no test
/// failing. So the rule has to see both sides: if `talante` names `tajante`,
/// `tajante.yml` says so too, in its own words.
///
/// Only the catalog counts. A confusable word nobody has written yet is a
/// perfectly good confusion — it is what most of them are — and a draft is not
/// yet a word the planner can introduce.
final class ConfusionSymmetryValidator extends LibraryValidator {
  const ConfusionSymmetryValidator();

  @override
  String get code => 'confusion_symmetry';

  @override
  String get description =>
      'a confusion that names another catalog word is declared by both files';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateLibrary(LibraryContext context) {
    final catalogue = [
      for (final word in context.words)
        if (word.status == WordStatus.approved) word,
    ];
    final index = Catalogue.of(catalogue);

    // slug -> the catalog words it declares, each with the name the file uses.
    final declared = <String, Map<String, String>>{
      for (final word in catalogue)
        word.slug: {
          for (final confusion in word.confusions)
            if (index.confusableOf(word, confusion) case final other?)
              other.slug: confusion.confusedWith,
        },
    };

    final issues = <Issue>[];
    for (final word in catalogue) {
      for (final entry in declared[word.slug]!.entries) {
        if (declared[entry.key]!.containsKey(word.slug)) continue;
        issues.add(
          _issue(
            this,
            entry.key,
            'confusions',
            '${word.slug}.yml declares "${word.lemma}" confusable with '
                '"${entry.value}", but ${entry.key}.yml does not declare '
                '"${word.lemma}" back; the interference rule only protects a '
                'pair both files carry',
          ),
        );
      }
    }
    return issues;
  }
}

/// A word that sounds affected never reaches the catalog.
final class PedantryGateValidator extends WordValidator {
  const PedantryGateValidator();

  @override
  String get code => 'pedantry_gate';

  @override
  String get description =>
      'status approved requires pedantry_risk <= 2 (learning-method §8)';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    if (word.status != WordStatus.approved) return const [];
    if (word.pedantryRisk <= context.options.maxPedantryForApproved) {
      return const [];
    }
    return [
      _issue(
        this,
        word.slug,
        'pedantry_risk',
        'pedantry_risk ${word.pedantryRisk} cannot reach status approved '
            '(max ${context.options.maxPedantryForApproved})',
      ),
    ];
  }
}

/// Proves every theme can feed the session planner for the next 90 days.
///
/// Each simulated day introduces one word per theme. A candidate is eligible
/// when it has not been introduced, is not confusable with anything introduced
/// in the last 6 days (learning-method §7) and does not belong to the same
/// semantic set as anything introduced in that window. A semantic set is a
/// shared `tags.comodin` or `tags.funcion` entry.
final class SchedulingSimulationValidator extends LibraryValidator {
  const SchedulingSimulationValidator();

  /// Days a freshly introduced word blocks its confusables and semantic peers.
  static const interferenceWindow = 6;

  @override
  String get code => 'scheduling_simulation';

  @override
  String get description =>
      'every theme keeps >= 3 eligible candidates on each of the next 90 days '
      'under the paronym and semantic-set rules';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateLibrary(LibraryContext context) {
    if (!context.options.enableCatalogSimulation) return const [];
    final approved = [
      for (final word in context.words)
        if (word.status == WordStatus.approved) word,
    ];
    if (approved.isEmpty) return const [];

    final issues = <Issue>[];
    final themes = <String>{
      for (final word in approved)
        for (final theme in word.themes) theme.slug,
    };
    for (final theme in themes.toList()..sort()) {
      final pool = [
        for (final word in approved)
          if (word.themes.any((t) => t.slug == theme)) word,
      ];
      final issue = _simulate(theme, pool, context);
      if (issue != null) issues.add(issue);
    }
    return issues;
  }

  Issue? _simulate(String theme, List<Word> pool, LibraryContext context) {
    final introduced = <String, int>{};
    for (var day = 1; day <= context.options.schedulingDays; day++) {
      final eligible = [
        for (final word in pool)
          if (!introduced.containsKey(word.slug) &&
              _isEligible(word, introduced, day, pool))
            word,
      ];
      if (eligible.length < context.options.minEligiblePerDay) {
        return _issue(
          this,
          '',
          'themes[$theme]',
          'theme "$theme" starves on day $day: ${eligible.length} eligible '
              'candidates, ${context.options.minEligiblePerDay} required '
              '(pool of ${pool.length} approved words)',
        );
      }
      introduced[eligible.first.slug] = day;
    }
    return null;
  }

  bool _isEligible(
    Word candidate,
    Map<String, int> introduced,
    int day,
    List<Word> pool,
  ) {
    for (final entry in introduced.entries) {
      if (day - entry.value > interferenceWindow) continue;
      final other = pool.firstWhere((w) => w.slug == entry.key);
      if (areConfusable(candidate, other)) return false;
      if (shareSemanticSet(candidate, other)) return false;
    }
    return true;
  }
}

/// learning-method §7: a confusion of either word points at the other.
bool areConfusable(Word a, Word b) {
  final aLemma = foldForComparison(a.lemma);
  final bLemma = foldForComparison(b.lemma);
  return a.confusions.any((c) => foldForComparison(c.confusedWith) == bLemma) ||
      b.confusions.any((c) => foldForComparison(c.confusedWith) == aLemma);
}

/// Two words belong to the same semantic set when the author declared the
/// same `semantic_set_id`, or — while neither declares one — when they replace
/// the same comodín or serve the same communicative function.
///
/// The declared id is the authority: two words that carry *different* ids are
/// deliberately not the same kind of word, whatever their tags say.
bool shareSemanticSet(Word a, Word b) {
  final aSet = a.semanticSetId;
  final bSet = b.semanticSetId;
  if (aSet != null && bSet != null) return aSet == bSet;
  return _shareTagSet(a, b);
}

bool _shareTagSet(Word a, Word b) {
  final aSets = <String>{
    for (final tag in a.tags.comodin) 'comodin:${foldForComparison(tag)}',
    for (final tag in a.tags.funcion) 'funcion:${foldForComparison(tag)}',
  };
  final bSets = <String>{
    for (final tag in b.tags.comodin) 'comodin:${foldForComparison(tag)}',
    for (final tag in b.tags.funcion) 'funcion:${foldForComparison(tag)}',
  };
  return aSets.intersection(bSets).isNotEmpty;
}
