import 'package:content/src/model/word.dart';
import 'package:content/src/text/spanish_morphology.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/structural.dart' show blankToken;
import 'package:content/src/validation/validator.dart';

Issue _issue(
  ContentValidator validator,
  String slug,
  String location,
  String message, {
  Severity? severity,
}) => Issue(
  code: validator.code,
  severity: severity ?? validator.severity,
  slug: slug,
  location: location,
  message: message,
);

/// Substitutes the correct option into the blank.
String filledSentence(Exercise exercise) =>
    exercise.sentence.replaceAll(blankToken, exercise.correctOption.text);

/// Gender, number and person agreement once the answer is in the sentence.
///
/// Deliberately narrow: it only fires on unambiguous conflicts, because a
/// false positive would block a correct word file.
final class AgreementValidator extends WordValidator {
  const AgreementValidator();

  @override
  String get code => 'agreement';

  @override
  String get description =>
      'the correct option agrees in gender, number and person with its slot';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final exercise in word.exercises) {
      if (exercise.options.where((o) => o.isCorrect).length != 1) continue;
      final where = 'exercises[${exercise.position}].sentence';
      final before = exercise.sentence.split(blankToken).first;
      final tokens = tokenizeWords(before).map(foldForComparison).toList();
      if (tokens.isEmpty) continue;
      final answer = exercise.correctOption.text;

      if (word.partOfSpeech == PartOfSpeech.verbo) {
        final pronoun = subjectPronouns[tokens.last];
        if (pronoun != null && !verbAgreement(answer).contains(pronoun)) {
          issues.add(
            _issue(
              this,
              word.slug,
              where,
              '"$answer" does not agree with the subject "${tokens.last}"',
            ),
          );
        }
        continue;
      }
      if (word.partOfSpeech != PartOfSpeech.adjetivo &&
          word.partOfSpeech != PartOfSpeech.sustantivo) {
        continue;
      }

      final head = _nominalHead(tokens);
      if (head == null) continue;
      final expected = head;
      final actual = nominalMorphology(answer);
      if (expected.gender != null &&
          actual.gender != null &&
          expected.gender != actual.gender) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            '"$answer" is ${actual.gender!.name} but the slot is ${expected.gender!.name}',
          ),
        );
      } else if (expected.number != actual.number) {
        issues.add(
          _issue(
            this,
            word.slug,
            where,
            '"$answer" is ${actual.number.name} but the slot is ${expected.number.name}',
          ),
        );
      }
    }
    return issues;
  }

  /// Walks back from the blank: skip degree modifiers, then either land on a
  /// determiner, or on a noun whose determiner sits one token further back.
  Morphology? _nominalHead(List<String> tokens) {
    var index = tokens.length - 1;
    while (index >= 0 && degreeModifiers.contains(tokens[index])) {
      index--;
    }
    if (index < 0) return null;
    final head = tokens[index];
    final asDeterminer = determiners[head];
    if (asDeterminer != null) return asDeterminer;
    if (agreementStopWords.contains(head)) return null;
    if (index == 0) return null;
    return determiners[tokens[index - 1]];
  }
}

/// A distractor must not be a collocation partner or a family member: those
/// are words the learner is being taught to use, not to reject.
final class DistractorOverlapValidator extends WordValidator {
  const DistractorOverlapValidator();

  @override
  String get code => 'distractor_overlap';

  @override
  String get description =>
      'no distractor appears in the word collocations or in its family';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    final collocationTokens = <String>{
      for (final collocation in word.collocations) ...foldedTokens(collocation),
    };
    final familyTokens = <String>{
      for (final member in word.family) ...foldedTokens(member),
    };
    for (final exercise in word.exercises) {
      for (final option in exercise.distractors) {
        final where =
            'exercises[${exercise.position}].options[${option.position}]';
        for (final token in foldedTokens(option.text)) {
          if (collocationTokens.contains(token)) {
            issues.add(
              _issue(
                this,
                word.slug,
                where,
                'distractor "${option.text}" appears in collocations',
              ),
            );
            break;
          }
          if (familyTokens.contains(token)) {
            issues.add(
              _issue(
                this,
                word.slug,
                where,
                'distractor "${option.text}" is a family member',
              ),
            );
            break;
          }
        }
      }
    }
    return issues;
  }
}

/// The answer must not be readable off the sentence or the general hint.
final class AnswerLeakageValidator extends WordValidator {
  const AnswerLeakageValidator();

  @override
  String get code => 'answer_leakage';

  @override
  String get description =>
      'lemma, family members and their stem never appear in the sentence or hint_general';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final length = context.options.leakStemLength;
    final isVerb = word.partOfSpeech == PartOfSpeech.verbo;
    final stems = <String>{
      contentStem(word.lemma, length, stripInfinitive: isVerb),
      for (final member in word.family)
        contentStem(member, length, stripInfinitive: true),
    }..removeWhere((s) => s.length < 4);
    final full = <String>{
      foldForComparison(word.lemma),
      for (final member in word.family) foldForComparison(member),
    };

    final issues = <Issue>[];
    void check(String slugPath, String text) {
      final folded = foldForComparison(text.replaceAll(blankToken, ' '));
      for (final needle in {...full, ...stems}) {
        if (folded.contains(needle)) {
          issues.add(
            _issue(
              this,
              word.slug,
              slugPath,
              'leaks the answer: "$needle" appears in the text',
            ),
          );
          return;
        }
      }
    }

    for (final exercise in word.exercises) {
      check('exercises[${exercise.position}].sentence', exercise.sentence);
      check(
        'exercises[${exercise.position}].hint_general',
        exercise.hintGeneral,
      );
    }
    return issues;
  }
}

/// Hints point at meaning, never at spelling.
final class HintCueValidator extends WordValidator {
  const HintCueValidator();

  static final _spellingCues = <RegExp>[
    RegExp('empieza (por|con)'),
    RegExp('comienza (por|con)'),
    RegExp('termina (en|con|por)'),
    RegExp('acaba (en|con)'),
    RegExp('(primera|ultima) letra'),
    RegExp('la[s]? letra[s]?'),
    // "se escribe con/sin <letra>" is a spelling cue; "¿así se escribe un
    // correo?" is about the text, not the orthography.
    RegExp('se escribe (con|sin|así|asi|la|el)'),
    RegExp('se deletrea'),
    RegExp('(lleva|sin|con) tilde'),
    RegExp('(con|sin) acento'),
    RegExp('silaba'),
  ];

  static final _quotedLetter = RegExp(
    '[«"“”‘’\']\\s*[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]\\s*[»"“”‘’\']',
  );

  @override
  String get code => 'hint_cue';

  @override
  String get description =>
      'hints carry no spelling cue and never quote a single letter';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    void check(String location, String? text) {
      if (text == null) return;
      final folded = foldForComparison(text);
      for (final cue in _spellingCues) {
        if (cue.hasMatch(folded)) {
          issues.add(
            _issue(
              this,
              word.slug,
              location,
              'spelling cue "${cue.pattern}" in a hint',
            ),
          );
          return;
        }
      }
      if (_quotedLetter.hasMatch(text)) {
        issues.add(
          _issue(this, word.slug, location, 'a hint quotes a single letter'),
        );
      }
    }

    for (final exercise in word.exercises) {
      check(
        'exercises[${exercise.position}].hint_general',
        exercise.hintGeneral,
      );
      for (final option in exercise.distractors) {
        check(
          'exercises[${exercise.position}].options[${option.position}].hint_specific',
          option.hintSpecific,
        );
      }
    }
    return issues;
  }
}

/// Word-count caps on the explanation and on both hint kinds.
final class LengthCapsValidator extends WordValidator {
  const LengthCapsValidator();

  @override
  String get code => 'length_caps';

  @override
  String get description =>
      'explanation <= 20 words, hint_general and hint_specific <= 25 words';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    final maxExplanation = context.options.explanationMaxWords;
    final maxHint = context.options.hintMaxWords;

    final explanationWords = countWords(word.explanation);
    if (explanationWords > maxExplanation) {
      issues.add(
        _issue(
          this,
          word.slug,
          'explanation',
          'explanation has $explanationWords words, the cap is $maxExplanation',
        ),
      );
    }
    for (final exercise in word.exercises) {
      final hintWords = countWords(exercise.hintGeneral);
      if (hintWords > maxHint) {
        issues.add(
          _issue(
            this,
            word.slug,
            'exercises[${exercise.position}].hint_general',
            'hint_general has $hintWords words, the cap is $maxHint',
          ),
        );
      }
      for (final option in exercise.distractors) {
        final specific = countWords(option.hintSpecific ?? '');
        if (specific > maxHint) {
          issues.add(
            _issue(
              this,
              word.slug,
              'exercises[${exercise.position}].options[${option.position}].hint_specific',
              'hint_specific has $specific words, the cap is $maxHint',
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// The exercise explanation names the answer and both distractors, spelled
/// exactly as the options are.
final class ExerciseExplanationCoverageValidator extends WordValidator {
  const ExerciseExplanationCoverageValidator();

  @override
  String get code => 'explanation_coverage';

  @override
  String get description =>
      'each exercise explanation names the answer and both distractors verbatim';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final exercise in word.exercises) {
      final folded = foldForComparison(exercise.explanation);
      final missing = <String>[
        for (final option in exercise.options)
          if (!folded.contains(foldForComparison(option.text))) option.text,
      ];
      if (missing.isNotEmpty) {
        issues.add(
          _issue(
            this,
            word.slug,
            'exercises[${exercise.position}].explanation',
            'explanation does not name: ${missing.join(', ')}',
          ),
        );
      }
    }
    return issues;
  }
}

/// A definition that uses the word, or a member of its family, explains nothing.
final class ExplanationCircularityValidator extends WordValidator {
  const ExplanationCircularityValidator();

  @override
  String get code => 'explanation_circularity';

  @override
  String get description =>
      'the explanation never uses the word itself or a family member';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final folded = foldForComparison(word.explanation);
    final offenders = <String>[
      for (final candidate in [word.lemma, ...word.family])
        if (folded.contains(foldForComparison(candidate))) candidate,
    ];
    if (offenders.isEmpty) return const [];
    return [
      _issue(
        this,
        word.slug,
        'explanation',
        'circular definition: it uses ${offenders.join(', ')}',
      ),
    ];
  }
}

/// Every content word of the explanation must be common.
///
/// Warns while `content/data/common_lemmas_es.txt` is missing, and blocks once
/// `dart run content:corpus` has produced it.
final class CommonVocabularyValidator extends WordValidator {
  const CommonVocabularyValidator();

  @override
  String get code => 'common_vocabulary';

  @override
  String get description =>
      'every content word of the explanation is in the top-N Spanish lemma list '
      '(warn until content/data/common_lemmas_es.txt exists)';

  @override
  Severity get severity => Severity.warn;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final list = context.commonLemmas;
    if (list == null || list.isEmpty) {
      return [
        _issue(
          this,
          word.slug,
          'explanation',
          'not checked: no frequency list in content/data — run '
              'dart run content:corpus to build one',
          severity: Severity.warn,
        ),
      ];
    }
    final rare = <String>[];
    for (final token in tokenizeWords(word.explanation)) {
      final folded = foldForComparison(token);
      if (spanishFunctionWords.contains(folded)) continue;
      if (lemmaCandidates(token).any(list.contains)) continue;
      rare.add(token);
    }
    if (rare.isEmpty) return const [];
    return [
      _issue(
        this,
        word.slug,
        'explanation',
        'not in the common-word list: ${rare.join(', ')}',
        severity: Severity.blocking,
      ),
    ];
  }
}
