import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/themes/data/dtos/theme_dto.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_dto.freezed.dart';
part 'word_dto.g.dart';

/// A `words` row with its embedded children (PostgREST resource embedding).
@freezed
abstract class WordDto with _$WordDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String slug,
    required String lemma,
    required String partOfSpeech,
    required List<String> syllables,
    required int stressedSyllable,
    required String explanation,
    required String exampleSentence,
    required String register,
    required int pedantryRisk,
    required int sortOrder,
    String? ipaLatam,
    String? ipaEs,
    String? usageTip,
    String? whenNotToUse,
    String? semanticSetId,
    @Default(<String>[]) List<String> collocations,
    @Default(<ReplacementDto>[]) List<ReplacementDto> replaces,
    @Default(<String>[]) List<String> family,
    @Default(<WordThemeDto>[]) List<WordThemeDto> wordThemes,
    @Default(<WordConfusionDto>[]) List<WordConfusionDto> wordConfusions,
    @Default(<ExerciseDto>[]) List<ExerciseDto> exercises,
    @Default(<ReadingDto>[]) List<ReadingDto> readings,
  }) = _WordDto;

  factory fromJson(Map<String, dynamic> json) => _$WordDtoFromJson(json);

  const new _();

  static const columns =
      'id, slug, lemma, part_of_speech, syllables, stressed_syllable, '
      'ipa_latam, ipa_es, explanation, example_sentence, register, '
      'pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, '
      'family, semantic_set_id, sort_order, '
      '${WordThemeDto.columns}, '
      // word_confusions has two FKs to words (word_id, confused_word_id), so
      // a bare `word_confusions(...)` embed is ambiguous to PostgREST
      // (PGRST201). Pin it to the word_id side: this word's own confusions.
      'word_confusions!word_confusions_word_id_fkey(id, word_id, '
      'confused_with, confused_word_id, difference, memory_trick), '
      // exercises also has two FKs to words (word_id, secondary_word_id --
      // the B side of a "contraste" item): the same PGRST201 ambiguity.
      'exercises!exercises_word_id_fkey(id, word_id, sentence, hint_general, '
      'explanation, position, '
      'exercise_options(id, text, is_correct, distractor_type, why_not, '
      'hint_specific, position)), '
      'readings(id, word_id, scene, conversation_type, title, body, '
      'before_phrase, after_phrase, position)';

  Word toDomain() => Word(
    id: id,
    slug: slug,
    lemma: lemma,
    partOfSpeech: PartOfSpeech.values.byName(partOfSpeech),
    syllables: syllables,
    stressedSyllable: stressedSyllable,
    ipaLatam: ipaLatam,
    ipaEs: ipaEs,
    explanation: explanation,
    exampleSentence: exampleSentence,
    register: WordRegister.values.byName(register),
    pedantryRisk: pedantryRisk,
    usageTip: usageTip,
    whenNotToUse: whenNotToUse,
    semanticSetId: semanticSetId,
    collocations: collocations,
    replaces: [
      for (final pair in replaces)
        Replacement(before: pair.before, after: pair.after),
    ],
    family: family,
    themeIds: themeIdsOf(wordThemes),
    sortOrder: sortOrder,
    confusions: [for (final row in wordConfusions) row.toDomain()],
    exercises: [
      for (final row in [
        ...exercises,
      ]..sort((a, b) => a.position.compareTo(b.position)))
        row.toDomain(),
    ],
    readings: [
      for (final row in [
        ...readings,
      ]..sort((a, b) => a.position.compareTo(b.position)))
        row.toDomain(),
    ],
  );
}

@freezed
abstract class ReplacementDto with _$ReplacementDto {
  const factory({required String before, required String after}) =
      _ReplacementDto;

  factory fromJson(Map<String, dynamic> json) => _$ReplacementDtoFromJson(json);
}

@freezed
abstract class WordConfusionDto with _$WordConfusionDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String wordId,
    required String confusedWith,
    required String difference,
    String? confusedWordId,
    String? memoryTrick,
  }) = _WordConfusionDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$WordConfusionDtoFromJson(json);

  const new _();

  WordConfusion toDomain() => WordConfusion(
    id: id,
    wordId: wordId,
    confusedWith: confusedWith,
    confusedWordId: confusedWordId,
    difference: difference,
    memoryTrick: memoryTrick,
  );
}

@freezed
abstract class ExerciseDto with _$ExerciseDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String wordId,
    required String sentence,
    required String hintGeneral,
    required String explanation,
    required int position,
    @Default(<ExerciseOptionDto>[]) List<ExerciseOptionDto> exerciseOptions,
  }) = _ExerciseDto;

  factory fromJson(Map<String, dynamic> json) => _$ExerciseDtoFromJson(json);

  const new _();

  ClozeExercise toDomain() => ClozeExercise(
    id: id,
    wordId: wordId,
    sentence: sentence,
    hintGeneral: hintGeneral,
    explanation: explanation,
    position: position,
    options: [
      for (final option in [
        ...exerciseOptions,
      ]..sort((a, b) => a.position.compareTo(b.position)))
        option.toDomain(),
    ],
  );
}

@freezed
abstract class ExerciseOptionDto with _$ExerciseOptionDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String text,
    required bool isCorrect,
    required int position,
    String? distractorType,
    String? whyNot,
    String? hintSpecific,
  }) = _ExerciseOptionDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$ExerciseOptionDtoFromJson(json);

  const new _();

  ExerciseOption toDomain() => ExerciseOption(
    id: id,
    text: text,
    isCorrect: isCorrect,
    position: position,
    distractorType: switch (distractorType) {
      'paronym' => DistractorType.paronym,
      'near_synonym' => DistractorType.nearSynonym,
      'register' => DistractorType.register,
      _ => null,
    },
    whyNot: whyNot,
    hintSpecific: hintSpecific,
  );
}

@freezed
abstract class ReadingDto with _$ReadingDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String wordId,
    required String scene,
    required String conversationType,
    required String title,
    required String body,
    required String beforePhrase,
    required String afterPhrase,
    required int position,
  }) = _ReadingDto;

  factory fromJson(Map<String, dynamic> json) => _$ReadingDtoFromJson(json);

  const new _();

  Reading toDomain() => Reading(
    id: id,
    wordId: wordId,
    scene: Scene.values.byName(scene),
    conversationType: ConversationType.values.byName(conversationType),
    title: title,
    body: body,
    beforePhrase: beforePhrase,
    afterPhrase: afterPhrase,
    position: position,
  );
}
