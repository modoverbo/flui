import 'package:content/src/model/word.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/validator.dart';

/// Cloze exercises a **new** word is authored with. See AUTHORING.md §3.
const authoredExerciseCount = 8;

/// Cloze exercises a word may not drop below.
///
/// A word only ever gets here by losing items to `content:prune`: the
/// adversarial gate found them ambiguous, and a word with six verified
/// exercises teaches better than one with eight where two are broken. Six is
/// the floor after pruning, never a licence to author fewer.
const minExerciseCount = 6;

/// Number of options per cloze.
const requiredOptionCount = 3;

/// Number of "En contexto" readings per word.
const requiredReadingCount = 3;

const blankToken = '{{blank}}';

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

/// `slug` must be the normalized form of `lemma`.
final class SlugMatchesLemmaValidator extends WordValidator {
  const SlugMatchesLemmaValidator();

  @override
  String get code => 'slug_matches_lemma';

  @override
  String get description => 'slug is the normalized lemma';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final expected = slugify(word.lemma);
    if (word.slug == expected) return const [];
    return [
      _issue(
        this,
        word.slug,
        'slug',
        'slug "${word.slug}" is not the normalized lemma "${word.lemma}" '
            '(expected "$expected")',
      ),
    ];
  }
}

/// Syllables must rebuild the lemma and the stress index must point inside.
final class SyllablesValidator extends WordValidator {
  const SyllablesValidator();

  @override
  String get code => 'syllables';

  @override
  String get description =>
      'syllables concatenate to the lemma and the stressed index is in range';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    if (word.syllables.isEmpty) {
      issues.add(_issue(this, word.slug, 'syllables', 'syllables is empty'));
      return issues;
    }
    final joined = foldForComparison(word.syllables.join());
    final lemma = foldForComparison(word.lemma.replaceAll(RegExp(r'\s+'), ''));
    if (joined != lemma) {
      issues.add(
        _issue(
          this,
          word.slug,
          'syllables',
          'syllables join to "$joined" but the lemma folds to "$lemma"',
        ),
      );
    }
    if (word.stressedSyllable < 1 ||
        word.stressedSyllable > word.syllables.length) {
      issues.add(
        _issue(
          this,
          word.slug,
          'stressed_syllable',
          'stressed_syllable ${word.stressedSyllable} is outside '
              '1..${word.syllables.length}',
        ),
      );
    }
    return issues;
  }
}

/// Six to eight exercises, each with exactly one `{{blank}}`.
final class ExerciseCountValidator extends WordValidator {
  const ExerciseCountValidator();

  @override
  String get code => 'exercise_count';

  @override
  String get description =>
      '$minExerciseCount..$authoredExerciseCount exercises (new words are '
      'authored with $authoredExerciseCount), one {{blank}} each, positions '
      '1..n';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    final count = word.exercises.length;
    final countIsLegal = count >= minExerciseCount &&
        count <= authoredExerciseCount;
    if (!countIsLegal) {
      issues.add(
        _issue(
          this,
          word.slug,
          'exercises',
          'expected $minExerciseCount..$authoredExerciseCount exercises, '
              'found $count',
        ),
      );
    }
    final positions = <int>{};
    for (final exercise in word.exercises) {
      final where = 'exercises[${exercise.position}]';
      if (!positions.add(exercise.position)) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            'duplicate exercise position ${exercise.position}',
          ),
        );
      }
      final blanks = blankToken.allMatches(exercise.sentence).length;
      if (blanks != 1) {
        issues.add(
          _issue(
            this,
            word.slug,
            '$where.sentence',
            'sentence must contain exactly one $blankToken, found $blanks',
          ),
        );
      }
    }
    // `content:prune` renumbers what it leaves behind, so a gap here means the
    // file was edited by hand and the app would show "ejercicio 8 de 7".
    final expected = {for (var i = 1; i <= count; i++) i};
    if (countIsLegal && !positions.containsAll(expected)) {
      issues.add(
        _issue(
          this,
          word.slug,
          'exercises',
          'exercise positions must be 1..$count, found ${positions.toList()..sort()}',
        ),
      );
    }
    return issues;
  }
}

/// Three options, exactly one correct, unique texts and unique positions.
final class OptionSetValidator extends WordValidator {
  const OptionSetValidator();

  @override
  String get code => 'option_set';

  @override
  String get description =>
      'exactly $requiredOptionCount options, exactly 1 correct, unique texts and positions';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final exercise in word.exercises) {
      final where = 'exercises[${exercise.position}].options';
      final options = exercise.options;
      if (options.length != requiredOptionCount) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            'expected $requiredOptionCount options, found ${options.length}',
          ),
        );
      }
      final correct = options.where((o) => o.isCorrect).length;
      if (correct != 1) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            'expected exactly 1 correct option, found $correct',
          ),
        );
      }
      final texts = <String>{};
      final positions = <int>{};
      for (final option in options) {
        if (!texts.add(foldForComparison(option.text))) {
          issues.add(
            _issue(
              this,
              word.slug,
              where,
              'duplicate option text "${option.text}"',
            ),
          );
        }
        if (!positions.add(option.position)) {
          issues.add(
            _issue(
              this,
              word.slug,
              where,
              'duplicate option position ${option.position}',
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// The correct option carries no distractor data; every distractor carries all
/// three fields.
final class DistractorFieldsValidator extends WordValidator {
  const DistractorFieldsValidator();

  @override
  String get code => 'distractor_fields';

  @override
  String get description =>
      'correct option has no distractor fields; distractors have type, why_not and hint_specific';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final exercise in word.exercises) {
      for (final option in exercise.options) {
        final where =
            'exercises[${exercise.position}].options[${option.position}]';
        if (option.isCorrect) {
          if (option.distractorType != null ||
              option.whyNot != null ||
              option.hintSpecific != null) {
            issues.add(
              _issue(
                this,
                word.slug,
                where,
                'the correct option must not carry distractor_type, why_not or hint_specific',
              ),
            );
          }
          continue;
        }
        final missing = <String>[
          if (option.distractorType == null) 'distractor_type',
          if (option.whyNot == null || option.whyNot!.trim().isEmpty) 'why_not',
          if (option.hintSpecific == null ||
              option.hintSpecific!.trim().isEmpty)
            'hint_specific',
        ];
        if (missing.isNotEmpty) {
          issues.add(
            _issue(
              this,
              word.slug,
              where,
              'distractor is missing ${missing.join(', ')}',
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// Distractor types an exercise set must cover, whatever else it carries.
const requiredDistractorTypes = <DistractorType>[
  DistractorType.paronym,
  DistractorType.register,
];

/// The required distractor types [present] does not cover, named the way the
/// `distractor_type_coverage` rule names them.
///
/// `content:prune` asks the same question about the exercises a prune would
/// leave behind, so the rule lives here once instead of twice.
List<String> missingDistractorTypes(Set<DistractorType> present) => [
  for (final type in requiredDistractorTypes)
    if (!present.contains(type)) distractorTypeNames[type]!,
];

/// Across the exercise set there must be at least one paronym distractor and
/// at least one register distractor. `content:prune` refuses to break this,
/// so a pruned word still trains both traps.
final class DistractorTypeCoverageValidator extends WordValidator {
  const DistractorTypeCoverageValidator();

  @override
  String get code => 'distractor_type_coverage';

  @override
  String get description =>
      'at least one paronym and one register distractor across the exercise set';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final types = <DistractorType>{
      for (final exercise in word.exercises)
        for (final option in exercise.distractors)
          if (option.distractorType != null) option.distractorType!,
    };
    final missing = missingDistractorTypes(types);
    if (missing.isEmpty) return const [];
    return [
      _issue(
        this,
        word.slug,
        'exercises',
        'the exercise set needs at least one distractor of each of: ${missing.join(', ')}',
      ),
    ];
  }
}

/// Exactly three readings, distinct scenes, at least two conversation types.
final class ReadingSetValidator extends WordValidator {
  const ReadingSetValidator();

  @override
  String get code => 'reading_set';

  @override
  String get description =>
      'exactly $requiredReadingCount readings, distinct scenes, >= 2 conversation types';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    if (word.readings.length != requiredReadingCount) {
      issues.add(
        _issue(
          this,
          word.slug,
          'readings',
          'expected $requiredReadingCount readings, found ${word.readings.length}',
        ),
      );
    }
    final scenes = word.readings.map((r) => r.scene).toSet();
    if (scenes.length != word.readings.length) {
      issues.add(
        _issue(
          this,
          word.slug,
          'readings',
          'readings must use distinct scenes',
        ),
      );
    }
    final types = word.readings.map((r) => r.conversationType).toSet();
    if (word.readings.isNotEmpty && types.length < 2) {
      issues.add(
        _issue(
          this,
          word.slug,
          'readings',
          'readings must cover at least 2 conversation types, found ${types.length}',
        ),
      );
    }
    final positions = word.readings.map((r) => r.position).toSet();
    if (positions.length != word.readings.length) {
      issues.add(
        _issue(this, word.slug, 'readings', 'duplicate reading positions'),
      );
    }
    return issues;
  }
}

/// At least one confusion, each with a difference, and at least one with a
/// memory trick. A confusion never points at the word itself.
final class ConfusionValidator extends WordValidator {
  const ConfusionValidator();

  @override
  String get code => 'confusions';

  @override
  String get description =>
      'at least one confusion with a difference, and one carrying a memory trick';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    if (word.confusions.isEmpty) {
      issues.add(
        _issue(
          this,
          word.slug,
          'confusions',
          'a word needs at least one confusion',
        ),
      );
      return issues;
    }
    for (final confusion in word.confusions) {
      final where = 'confusions[${confusion.confusedWith}]';
      if (confusion.difference.trim().isEmpty) {
        issues.add(_issue(this, word.slug, where, 'difference is empty'));
      }
      if (foldForComparison(confusion.confusedWith) ==
          foldForComparison(word.lemma)) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            'a word cannot be confusable with itself',
          ),
        );
      }
    }
    final hasTrick = word.confusions.any(
      (c) => (c.memoryTrick ?? '').trim().isNotEmpty,
    );
    if (!hasTrick) {
      issues.add(
        _issue(
          this,
          word.slug,
          'confusions',
          'at least one confusion must carry a memory_trick',
        ),
      );
    }
    return issues;
  }
}

/// At least two before/after replacement pairs, and the "after" side must
/// actually use the word: `replaces` is the heart of the product.
final class ReplacesValidator extends WordValidator {
  const ReplacesValidator();

  @override
  String get code => 'replaces';

  @override
  String get description =>
      'at least 2 before/after pairs, each "after" using the word';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    if (word.replaces.length < 2) {
      issues.add(
        _issue(
          this,
          word.slug,
          'replaces',
          'expected at least 2 replacement pairs, found ${word.replaces.length}',
        ),
      );
    }
    final lemmaStem = contentStem(
      word.lemma,
      context.options.leakStemLength,
      stripInfinitive: word.partOfSpeech == PartOfSpeech.verbo,
    );
    for (var i = 0; i < word.replaces.length; i++) {
      final pair = word.replaces[i];
      final where = 'replaces[$i]';
      if (pair.before.trim().isEmpty || pair.after.trim().isEmpty) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            'before and after must both be filled',
          ),
        );
        continue;
      }
      if (!foldForComparison(pair.after).contains(lemmaStem)) {
        issues.add(
          _issue(
            this,
            word.slug,
            '$where.after',
            '"${pair.after}" does not use the word (stem "$lemmaStem")',
          ),
        );
      }
      if (foldForComparison(pair.before).contains(lemmaStem)) {
        issues.add(
          _issue(
            this,
            word.slug,
            '$where.before',
            '"${pair.before}" already uses the word, so it is not a "before"',
          ),
        );
      }
    }
    return issues;
  }
}
