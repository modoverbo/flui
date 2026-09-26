import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';

/// September 2026 dates for readable tests (`day(13)` is a Sunday).
LocalDate day(int day, {int month = 9}) => LocalDate(2026, month, day);

ClozeExercise buildExercise({
  required String wordId,
  int position = 1,
  String? id,
  String correct = 'perspicaz',
  List<String> distractors = const ['suspicaz', 'perspicuo'],
}) {
  final exerciseId = id ?? '$wordId-e$position';
  return ClozeExercise(
    id: exerciseId,
    wordId: wordId,
    sentence: 'Frase $position de $wordId: es tan {{blank}} que lo vio.',
    hintGeneral: 'Pista general $position',
    explanation: 'Explicación $position',
    position: position,
    options: [
      ExerciseOption(
        id: '$exerciseId-o1',
        text: correct,
        isCorrect: true,
        position: 1,
      ),
      for (final (index, text) in distractors.indexed)
        ExerciseOption(
          id: '$exerciseId-o${index + 2}',
          text: text,
          isCorrect: false,
          position: index + 2,
          distractorType: DistractorType.paronym,
          whyNot: 'Por qué no $text',
          hintSpecific: 'Pista de $text',
        ),
    ],
  );
}

Reading buildReading({
  required String wordId,
  int position = 1,
  Scene scene = Scene.trabajo,
}) => Reading(
  id: '$wordId-r$position',
  wordId: wordId,
  scene: scene,
  conversationType: ConversationType.practica,
  title: 'Escena $position',
  body: 'Cuerpo $position con $wordId.',
  beforePhrase: 'Antes $position',
  afterPhrase: 'Ahora $position',
  position: position,
);

Word buildWord({
  String id = 'w1',
  String? lemma,
  int sortOrder = 1,
  PartOfSpeech partOfSpeech = PartOfSpeech.adjetivo,
  List<String> family = const [],
  List<WordConfusion> confusions = const [],
  List<String> themeIds = const [],
  String? semanticSetId,
  int exerciseCount = 3,
  int readingCount = 3,
}) {
  final wordLemma = lemma ?? 'palabra$sortOrder';
  return Word(
    id: id,
    slug: wordLemma,
    lemma: wordLemma,
    partOfSpeech: partOfSpeech,
    syllables: const ['pa', 'la', 'bra'],
    stressedSyllable: 2,
    explanation: 'Explicación de $wordLemma',
    exampleSentence: 'Un ejemplo con $wordLemma dentro.',
    register: WordRegister.neutral,
    pedantryRisk: 1,
    sortOrder: sortOrder,
    family: family,
    themeIds: themeIds,
    semanticSetId: semanticSetId,
    confusions: confusions,
    replaces: [Replacement(before: 'antes $wordLemma', after: wordLemma)],
    exercises: [
      for (var p = 1; p <= exerciseCount; p++)
        buildExercise(wordId: id, position: p, correct: wordLemma),
    ],
    readings: [
      for (var p = 1; p <= readingCount; p++)
        buildReading(wordId: id, position: p),
    ],
  );
}

Theme buildTheme({
  String? id,
  String? slug,
  ThemeFamily family = ThemeFamily.trabajo,
  ThemeContentType contentType = ThemeContentType.wordDriven,
  ThemeStatus status = ThemeStatus.live,
  int sortOrder = 1,
  String? name,
}) {
  final themeSlug = slug ?? 'tema$sortOrder';
  return Theme(
    id: id ?? themeSlug,
    slug: themeSlug,
    family: family,
    name: name ?? 'Tema $sortOrder',
    tagline: 'Una línea de $themeSlug.',
    jtbd: 'Quiero practicar $themeSlug.',
    contentType: contentType,
    status: status,
    sortOrder: sortOrder,
  );
}

WordConfusion confusion({
  required String wordId,
  required String confusedWith,
  String? confusedWordId,
}) => WordConfusion(
  id: '$wordId-$confusedWith',
  wordId: wordId,
  confusedWith: confusedWith,
  confusedWordId: confusedWordId,
  difference: 'Diferencia',
);

WordProgress buildProgress({
  String wordId = 'w1',
  WordState state = WordState.practica,
  LocalDate? introducedOn,
  Set<LocalDate> successDays = const {},
  bool formRecallDone = false,
  bool productionDone = false,
  int ladderStep = 0,
  LocalDate? nextDueOn,
  Grade? lastGrade,
}) => WordProgress(
  wordId: wordId,
  state: state,
  introducedOn: introducedOn ?? day(1),
  firstTrySuccessDays: successDays,
  formRecallDone: formRecallDone,
  productionDone: productionDone,
  ladderStep: ladderStep,
  nextDueOn: nextDueOn,
  lastGrade: lastGrade,
);
