import 'package:content/src/model/word.dart';

/// Whether a string talks *to* the learner or tells a story.
///
/// Instructional copy must follow the brand voice to the letter; narrative
/// copy is fiction where a character may, for instance, use "usted".
enum TextRole { instructional, narrative }

final class WordText {
  const WordText(this.location, this.value, this.role);

  final String location;
  final String value;
  final TextRole role;
}

/// Every Spanish string of a word, with a stable location path.
List<WordText> wordTexts(Word word) {
  final texts = <WordText>[
    WordText('explanation', word.explanation, TextRole.instructional),
    WordText('example_sentence', word.exampleSentence, TextRole.narrative),
    if (word.usageTip != null)
      WordText('usage_tip', word.usageTip!, TextRole.instructional),
    if (word.whenNotToUse != null)
      WordText('when_not_to_use', word.whenNotToUse!, TextRole.instructional),
  ];
  for (var i = 0; i < word.collocations.length; i++) {
    texts.add(
      WordText(
        'collocations[$i]',
        word.collocations[i],
        TextRole.instructional,
      ),
    );
  }
  for (var i = 0; i < word.replaces.length; i++) {
    texts
      ..add(
        WordText(
          'replaces[$i].before',
          word.replaces[i].before,
          TextRole.instructional,
        ),
      )
      ..add(
        WordText(
          'replaces[$i].after',
          word.replaces[i].after,
          TextRole.instructional,
        ),
      );
  }
  for (final confusion in word.confusions) {
    final where = 'confusions[${confusion.confusedWith}]';
    texts.add(
      WordText(
        '$where.difference',
        confusion.difference,
        TextRole.instructional,
      ),
    );
    if (confusion.memoryTrick != null) {
      texts.add(
        WordText(
          '$where.memory_trick',
          confusion.memoryTrick!,
          TextRole.instructional,
        ),
      );
    }
  }
  for (final exercise in word.exercises) {
    final where = 'exercises[${exercise.position}]';
    texts
      ..add(WordText('$where.sentence', exercise.sentence, TextRole.narrative))
      ..add(
        WordText(
          '$where.hint_general',
          exercise.hintGeneral,
          TextRole.instructional,
        ),
      )
      ..add(
        WordText(
          '$where.explanation',
          exercise.explanation,
          TextRole.instructional,
        ),
      );
    for (final option in exercise.options) {
      final optionWhere = '$where.options[${option.position}]';
      texts.add(
        WordText('$optionWhere.text', option.text, TextRole.instructional),
      );
      if (option.whyNot != null) {
        texts.add(
          WordText(
            '$optionWhere.why_not',
            option.whyNot!,
            TextRole.instructional,
          ),
        );
      }
      if (option.hintSpecific != null) {
        texts.add(
          WordText(
            '$optionWhere.hint_specific',
            option.hintSpecific!,
            TextRole.instructional,
          ),
        );
      }
    }
  }
  for (final reading in word.readings) {
    final where = 'readings[${reading.position}]';
    texts
      ..add(WordText('$where.title', reading.title, TextRole.narrative))
      ..add(WordText('$where.body', reading.body, TextRole.narrative))
      ..add(
        WordText(
          '$where.before_phrase',
          reading.beforePhrase,
          TextRole.instructional,
        ),
      )
      ..add(
        WordText(
          '$where.after_phrase',
          reading.afterPhrase,
          TextRole.instructional,
        ),
      );
  }
  return texts;
}
