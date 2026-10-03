import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/vocabulary/data/dtos/word_dto.dart';
import 'package:flui/features/vocabulary/data/dtos/word_progress_dto.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/data/supabase_content_repository.dart';
import 'package:flui/features/vocabulary/data/supabase_word_progress_repository.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/learning_builders.dart';
import '../../../helpers/supabase_recorder.dart';

Map<String, Object?> wordRow() => {
  'id': 'w1',
  'slug': 'zanjar',
  'lemma': 'zanjar',
  'part_of_speech': 'verbo',
  'syllables': ['zan', 'jar'],
  'stressed_syllable': 2,
  'ipa_latam': '[sanˈxar]',
  'ipa_es': null,
  'explanation': 'Terminar algo de forma definitiva.',
  'example_sentence': 'Zanjemos el tema.',
  'register': 'neutral',
  'pedantry_risk': 1,
  'usage_tip': null,
  'when_not_to_use': 'No para cosas físicas.',
  'collocations': ['zanjar un tema'],
  'replaces': [
    {'before': 'Cerremos el tema', 'after': 'Zanjemos el tema'},
  ],
  'family': ['zanja'],
  'sort_order': 8,
  'word_confusions': [
    {
      'id': 'c1',
      'word_id': 'w1',
      'confused_with': 'saldar',
      'confused_word_id': null,
      'difference': 'Saldar es pagar.',
      'memory_trick': null,
    },
  ],
  'exercises': [
    {
      'id': 'e2',
      'word_id': 'w1',
      'sentence': 'Lo {{blank}} ayer.',
      'hint_general': 'Terminar.',
      'explanation': 'Zanjó.',
      'position': 2,
      'exercise_options': [
        {
          'id': 'o2',
          'text': 'aplazó',
          'is_correct': false,
          'distractor_type': 'near_synonym',
          'why_not': 'Es posponer.',
          'hint_specific': '¿Lo deja para después?',
          'position': 2,
        },
        {
          'id': 'o1',
          'text': 'zanjó',
          'is_correct': true,
          'distractor_type': null,
          'why_not': null,
          'hint_specific': null,
          'position': 1,
        },
      ],
    },
    {
      'id': 'e1',
      'word_id': 'w1',
      'sentence': 'Hay que {{blank}}lo.',
      'hint_general': 'Terminar.',
      'explanation': 'Zanjar.',
      'position': 1,
      'exercise_options': <Object?>[],
    },
  ],
  'readings': [
    {
      'id': 'r1',
      'word_id': 'w1',
      'scene': 'familia',
      'conversation_type': 'emocional',
      'title': 'El malentendido',
      'body': 'Quiero zanjarlo hoy.',
      'before_phrase': 'Olvidémonos.',
      'after_phrase': 'Zanjémoslo.',
      'position': 1,
    },
  ],
};

void main() {
  group('WordDto', () {
    test('maps a nested words row to a Word ordered by position', () {
      final word = WordDto.fromJson(wordRow()).toDomain();

      expect(word.partOfSpeech, PartOfSpeech.verbo);
      expect(word.syllables, ['zan', 'jar']);
      expect(word.ipaEs, isNull);
      expect(word.replaces.single.after, 'Zanjemos el tema');
      expect(word.confusions.single.confusedWith, 'saldar');
      expect(word.exercises.map((e) => e.id), ['e1', 'e2']);
      final options = word.exercises.last.options;
      expect(options.map((o) => o.text), ['zanjó', 'aplazó']);
      expect(options.last.distractorType, DistractorType.nearSynonym);
      expect(word.readings.single.scene, Scene.familia);
      expect(word.readings.single.conversationType, ConversationType.emocional);
    });

    test('selects every column the mapper reads', () {
      for (final column in [
        'part_of_speech',
        'exercise_options(',
        'readings(',
        'before_phrase',
        'hint_specific',
      ]) {
        expect(WordDto.columns, contains(column));
      }
    });

    test(
      'disambiguates the word_confusions embed by its word_id relationship',
      () {
        // word_confusions has two FKs to words (word_id and confused_word_id),
        // so PostgREST refuses a bare `word_confusions(...)` embed with
        // PGRST201 ("more than one relationship was found"). This must
        // always name the word_id side explicitly, or every screen that
        // reads the catalog (Hoy, Entrenar, Palabras, diagnosis) fails.
        expect(
          WordDto.columns,
          contains('word_confusions!word_confusions_word_id_fkey('),
        );
      },
    );

    test('disambiguates the exercises embed by its word_id relationship', () {
      // exercises also has two FKs to words (word_id and secondary_word_id,
      // the B side of a "contraste" item), the same PGRST201 ambiguity.
      expect(WordDto.columns, contains('exercises!exercises_word_id_fkey('));
    });
  });

  group('WordProgressDto', () {
    final progress = WordProgress(
      wordId: 'w1',
      state: WordState.practica,
      introducedOn: day(1),
      firstTrySuccessDays: {day(11), day(4)},
      formRecallDone: true,
      ladderStep: 2,
      nextDueOn: day(18),
      lastGrade: Grade.good,
      lastReviewedAt: DateTime.utc(2026, 9, 11, 12),
    );

    test('writes the row with the user, ISO dates and UTC timestamps', () {
      final json = WordProgressDto.fromDomain(progress, userId: 'u1').toJson();

      expect(json, {
        'user_id': 'u1',
        'word_id': 'w1',
        'state': 'practica',
        'introduced_on': '2026-09-01',
        'first_try_success_days': ['2026-09-04', '2026-09-11'],
        'form_recall_done': true,
        'production_done': false,
        'ladder_step': 2,
        'next_due_on': '2026-09-18',
        'last_grade': 'good',
        'last_reviewed_at': '2026-09-11T12:00:00.000Z',
      });
    });

    test('round-trips through JSON', () {
      final json = WordProgressDto.fromDomain(progress, userId: 'u1').toJson();

      expect(WordProgressDto.fromJson(json).toDomain(), progress);
    });

    test('reads nullable columns', () {
      final dto = WordProgressDto.fromJson({
        'word_id': 'w1',
        'state': 'nueva',
        'introduced_on': '2026-09-13',
        'first_try_success_days': <String>[],
        'form_recall_done': false,
        'production_done': false,
        'ladder_step': 0,
        'next_due_on': null,
        'last_grade': null,
        'last_reviewed_at': null,
      });

      expect(
        dto.toDomain(),
        WordProgress(
          wordId: 'w1',
          state: WordState.nueva,
          introducedOn: LocalDate(2026, 9, 13),
        ),
      );
    });
  });

  group('FakeContentRepository', () {
    test('serves the seed words in order', () async {
      final result = await FakeContentRepository().fetchCatalog();

      final words = result.valueOrNull!;
      // The catalog grows every authoring round; the order is the invariant.
      expect(words, hasLength(seedWords.length));
      expect(words.first.lemma, 'perspicaz');
      expect(
        words.map((w) => w.sortOrder).toList(),
        orderedEquals(words.map((w) => w.sortOrder).toList()..sort()),
      );
    });

    test('returns a queued failure once', () async {
      final repository = FakeContentRepository()
        ..nextFailure = const NetworkFailure();

      expect(await repository.fetchCatalog(), isA<Err<List<Word>>>());
      expect((await repository.fetchCatalog()).isOk, isTrue);
    });
  });

  group('FakeWordProgressRepository', () {
    test('stores rows per user and replaces by word', () async {
      var user = 'a';
      final repository = FakeWordProgressRepository(currentUserId: () => user);
      await repository.saveProgress(buildProgress());
      await repository.saveProgress(buildProgress(state: WordState.tuya));

      expect(
        (await repository.fetchProgress()).valueOrNull!.single.state,
        WordState.tuya,
      );
      user = 'b';
      expect((await repository.fetchProgress()).valueOrNull, isEmpty);
    });

    test('fails without a signed-in user', () async {
      final repository = FakeWordProgressRepository(currentUserId: () => null);

      expect((await repository.fetchProgress()).isOk, isFalse);
    });
  });

  group('SupabaseContentRepository', () {
    test('selects published words with children, ascending order', () async {
      final recorder = SupabaseRecorder(respond: (_) => [wordRow()]);
      addTearDown(recorder.dispose);

      final result = await SupabaseContentRepository(recorder.client)
          .fetchCatalog();

      expect(result.valueOrNull!.single.lemma, 'zanjar');
      final url = recorder.last.url;
      expect(url.path, '/rest/v1/words');
      expect(url.queryParameters['published'], 'eq.true');
      expect(url.queryParameters['order'], 'sort_order.asc.nullslast');
      expect(url.queryParameters['select'], contains('exercise_options('));
    });

    test('pages through a catalog past the PostgREST cap', () async {
      // A catalog bigger than `max_rows` used to lose its tail silently.
      final recorder = SupabaseRecorder(
        respond: (request) => request.url.queryParameters['offset'] == '0'
            ? List.filled(1000, wordRow())
            : [wordRow()],
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseContentRepository(recorder.client)
          .fetchCatalog();

      expect(result.valueOrNull, hasLength(1001));
      expect(recorder.requests, hasLength(2));
    });

    test('maps transport errors to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseContentRepository(recorder.client)
          .fetchCatalog();

      expect(result.failureOrNull, const NetworkFailure());
    });
  });

  group('SupabaseWordProgressRepository', () {
    test('pages through every row', () async {
      final row = WordProgressDto.fromDomain(
        buildProgress(),
        userId: 'u1',
      ).toJson();
      final recorder = SupabaseRecorder(
        respond: (request) => request.url.queryParameters['offset'] == '0'
            ? List.filled(SupabaseWordProgressRepository.pageSize, row)
            : [row],
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseWordProgressRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).fetchProgress();

      expect(result.valueOrNull, hasLength(1001));
      expect(recorder.requests, hasLength(2));
      expect(recorder.requests.last.url.path, '/rest/v1/word_progress');
      expect(recorder.requests.last.url.queryParameters['offset'], '1000');
    });

    test('upserts on the (user_id, word_id) key', () async {
      final recorder = SupabaseRecorder(respond: (_) => null);
      addTearDown(recorder.dispose);

      final result = await SupabaseWordProgressRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).saveProgress(buildProgress(wordId: 'w9'));

      expect(result.isOk, isTrue);
      expect(recorder.last.method, 'POST');
      expect(
        recorder.last.url.queryParameters['on_conflict'],
        'user_id,word_id',
      );
      expect(recorder.last.headers['Prefer'], contains('merge-duplicates'));
      expect(recorder.bodyOf(recorder.last), containsPair('word_id', 'w9'));
    });

    test('refuses to write without a user', () async {
      final recorder = SupabaseRecorder();
      addTearDown(recorder.dispose);

      final result = await SupabaseWordProgressRepository(
        recorder.client,
        currentUserId: () => null,
      ).saveProgress(buildProgress());

      expect(result.isOk, isFalse);
      expect(recorder.requests, isEmpty);
    });
  });
}
