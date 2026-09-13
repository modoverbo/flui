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
  String message,
) => Issue(
  code: validator.code,
  severity: validator.severity,
  slug: slug,
  location: location,
  message: message,
);

final class _Sentence {
  const _Sentence(this.slug, this.location, this.text);

  final String slug;
  final String location;
  final String text;
}

List<_Sentence> _librarySentences(LibraryContext context) => [
  for (final word in context.words) ...[
    _Sentence(word.slug, 'example_sentence', word.exampleSentence),
    for (final exercise in word.exercises)
      _Sentence(
        word.slug,
        'exercises[${exercise.position}].sentence',
        exercise.sentence,
      ),
  ],
];

/// No sentence may be reused, or near-reused, anywhere in the library.
///
/// Candidate pairs come from an inverted shingle index, so the check stays
/// linear-ish instead of quadratic on a catalog of thousands of sentences.
final class SentenceUniquenessValidator extends LibraryValidator {
  const SentenceUniquenessValidator();

  @override
  String get code => 'sentence_uniqueness';

  @override
  String get description =>
      'no two sentences in the library exceed the shingle-Jaccard threshold';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateLibrary(LibraryContext context) {
    final sentences = _librarySentences(context);
    final size = context.options.sentenceShingleSize;
    final threshold = context.options.sentenceJaccardThreshold;
    final fingerprints = [
      for (final sentence in sentences)
        shingles(sentence.text.replaceAll(blankToken, ' '), size),
    ];

    final index = <String, List<int>>{};
    for (var i = 0; i < fingerprints.length; i++) {
      for (final shingle in fingerprints[i]) {
        index.putIfAbsent(shingle, () => []).add(i);
      }
    }

    final seen = <String>{};
    final issues = <Issue>[];
    for (var i = 0; i < fingerprints.length; i++) {
      final candidates = <int>{};
      for (final shingle in fingerprints[i]) {
        for (final other in index[shingle]!) {
          if (other > i) candidates.add(other);
        }
      }
      for (final j in candidates) {
        final similarity = jaccard(fingerprints[i], fingerprints[j]);
        if (similarity < threshold) continue;
        if (!seen.add('$i:$j')) continue;
        issues.add(
          _issue(
            this,
            sentences[i].slug,
            sentences[i].location,
            'sentence is ${(similarity * 100).round()}% similar to '
            '${sentences[j].slug} ${sentences[j].location}',
          ),
        );
      }
    }
    return issues;
  }
}

/// The eight sentences of a word must not all start the same way, and no
/// syntactic frame may dominate the library.
final class TemplateDiversityValidator extends LibraryValidator {
  const TemplateDiversityValidator();

  @override
  String get code => 'template_diversity';

  @override
  String get description =>
      'at most 2 sentences of a word share an opening trigram, and no syntactic '
      'frame is reused more than K times library-wide';

  @override
  Severity get severity => Severity.blocking;

  /// Coarse syntactic signature: the function-word skeleton plus where the
  /// blank falls in the sentence.
  static String frameOf(String sentence) {
    final tokens = foldedTokens(sentence.replaceAll(blankToken, ' _ '));
    final skeleton = <String>[
      for (final token in tokens)
        if (spanishFunctionWords.contains(token)) token,
    ];
    final blankIndex = sentence.indexOf(blankToken);
    final bucket = blankIndex < 0
        ? 'none'
        : (blankIndex * 3 ~/ (sentence.length + 1)).toString();
    return '${skeleton.take(6).join(' ')}|$bucket';
  }

  @override
  List<Issue> validateLibrary(LibraryContext context) {
    final issues = <Issue>[];
    final limit = context.options.openingTrigramLimitPerWord;

    for (final word in context.words) {
      final counts = <String, int>{};
      for (final exercise in word.exercises) {
        final opening = openingNgram(exercise.sentence, 3);
        if (opening == null) continue;
        counts[opening] = (counts[opening] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        if (entry.value > limit) {
          issues.add(
            _issue(
              this,
              word.slug,
              'exercises',
              '${entry.value} sentences open with "${entry.key}"; the cap is $limit',
            ),
          );
        }
      }
    }

    final frames = <String, List<String>>{};
    for (final sentence in _librarySentences(context)) {
      frames
          .putIfAbsent(frameOf(sentence.text), () => [])
          .add('${sentence.slug} ${sentence.location}');
    }
    for (final entry in frames.entries) {
      if (entry.value.length > context.options.frameReuseLimit) {
        issues.add(
          _issue(
            this,
            '',
            'library',
            'syntactic frame "${entry.key}" is reused ${entry.value.length} times '
                '(limit ${context.options.frameReuseLimit}); first offenders: '
                '${entry.value.take(3).join(', ')}',
          ),
        );
      }
    }
    return issues;
  }
}

/// No single personal name may carry more than N% of the library's sentences.
final class NameDiversityValidator extends LibraryValidator {
  const NameDiversityValidator();

  /// Curated Spanish given names. Not exhaustive: it covers the names an
  /// authoring agent reaches for.
  static const spanishGivenNames = <String>{
    'adriana',
    'alejandro',
    'alicia',
    'alvaro',
    'ana',
    'andrea',
    'andres',
    'antonio',
    'beatriz',
    'benjamin',
    'blanca',
    'bruno',
    'camila',
    'carla',
    'carlos',
    'carmen',
    'carolina',
    'cecilia',
    'celia',
    'clara',
    'claudia',
    'cristina',
    'daniel',
    'daniela',
    'david',
    'diego',
    'elena',
    'elisa',
    'emilio',
    'emma',
    'enrique',
    'ernesto',
    'esteban',
    'eva',
    'felipe',
    'fernanda',
    'fernando',
    'francisco',
    'gabriel',
    'gabriela',
    'gloria',
    'gonzalo',
    'guillermo',
    'hector',
    'hugo',
    'ignacio',
    'ines',
    'irene',
    'isabel',
    'ivan',
    'javier',
    'joaquin',
    'jorge',
    'jose',
    'juan',
    'julia',
    'julian',
    'laura',
    'leonor',
    'lorena',
    'lucas',
    'lucia',
    'luis',
    'luisa',
    'macarena',
    'manuel',
    'marcos',
    'maria',
    'mariana',
    'marta',
    'martin',
    'mateo',
    'miguel',
    'monica',
    'natalia',
    'nicolas',
    'noelia',
    'nuria',
    'olga',
    'oscar',
    'pablo',
    'patricia',
    'paula',
    'pedro',
    'pilar',
    'rafael',
    'ramiro',
    'ramon',
    'raul',
    'renata',
    'ricardo',
    'roberto',
    'rocio',
    'rodrigo',
    'rosa',
    'ruben',
    'salvador',
    'samuel',
    'sandra',
    'santiago',
    'sara',
    'sergio',
    'silvia',
    'simon',
    'sofia',
    'susana',
    'teresa',
    'tomas',
    'valentina',
    'valeria',
    'veronica',
    'vicente',
    'victor',
    'virginia',
    'ximena',
  };

  @override
  String get code => 'name_diversity';

  @override
  String get description =>
      'no personal name appears in more than N% of the library sentences';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateLibrary(LibraryContext context) {
    final texts = <String>[
      for (final word in context.words) ...[
        for (final exercise in word.exercises) exercise.sentence,
        for (final reading in word.readings) reading.body,
      ],
    ];
    if (texts.length < context.options.nameCheckMinSentences) return const [];

    final counts = <String, int>{};
    for (final text in texts) {
      final names = <String>{
        for (final token in foldedTokens(text))
          if (spanishGivenNames.contains(token)) token,
      };
      for (final name in names) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final limit = context.options.namePercentLimit;
    final issues = <Issue>[];
    for (final entry in counts.entries) {
      final share = entry.value * 100 / texts.length;
      if (share > limit) {
        issues.add(
          _issue(
            this,
            '',
            'library',
            'the name "${entry.key}" appears in ${share.toStringAsFixed(1)}% of '
                'the library sentences; the cap is $limit%',
          ),
        );
      }
    }
    return issues;
  }
}
