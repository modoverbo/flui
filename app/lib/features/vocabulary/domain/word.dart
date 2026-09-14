import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'word.freezed.dart';

enum PartOfSpeech { adjetivo, adverbio, conector, sustantivo, verbo }

enum WordRegister { neutral, culto, coloquial }

/// A vague phrase and the sharper phrase that uses the word.
@freezed
abstract class Replacement with _$Replacement {
  const factory({required String before, required String after}) = _Replacement;
}

/// A paronym or near-synonym of a word (`word_confusions` row).
@freezed
abstract class WordConfusion with _$WordConfusion {
  const factory({
    required String id,
    required String wordId,
    required String confusedWith,
    required String difference,

    /// Set when the confusable word is itself in the catalog.
    String? confusedWordId,
    String? memoryTrick,
  }) = _WordConfusion;
}

/// A published catalog word with everything attached to it.
@freezed
abstract class Word with _$Word {
  const factory({
    required String id,
    required String slug,
    required String lemma,
    required PartOfSpeech partOfSpeech,
    required List<String> syllables,

    /// 1-based index into [syllables].
    required int stressedSyllable,
    required String explanation,
    required String exampleSentence,
    required WordRegister register,
    required int pedantryRisk,
    required int sortOrder,
    String? ipaLatam,
    String? ipaEs,
    String? usageTip,
    String? whenNotToUse,

    /// Synonym / antonym / category-mate group (`words.semantic_set_id`). Two
    /// words of one set are never introduced within 7 days of each other; see
    /// `SemanticSetRule`.
    String? semanticSetId,
    @Default(<String>[]) List<String> collocations,
    @Default(<Replacement>[]) List<Replacement> replaces,
    @Default(<String>[]) List<String> family,

    /// Themes this word belongs to (`word_themes`), most relevant first. A
    /// theme filters the new-word candidate pool and nothing else.
    @Default(<String>[]) List<String> themeIds,
    @Default(<WordConfusion>[]) List<WordConfusion> confusions,
    @Default(<ClozeExercise>[]) List<ClozeExercise> exercises,
    @Default(<Reading>[]) List<Reading> readings,
  }) = _Word;

  const new _();

  /// Written forms that count as using this word (typed recall, production).
  WordForms get forms => WordForms(
    lemma: lemma,
    isVerb: partOfSpeech == PartOfSpeech.verbo,
    extraForms: [
      ...family,
      for (final exercise in exercises) exercise.correctOption.text,
    ],
  );
}
