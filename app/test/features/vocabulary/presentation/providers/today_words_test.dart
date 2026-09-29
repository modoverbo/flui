import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/today_words.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';
import '../../../../helpers/learning_fakes.dart';
import '../../../../helpers/test_container.dart';

void main() {
  late LearningFakes fakes;
  late ProviderContainer container;

  setUp(() {
    fakes = LearningFakes();
    container = createTestContainer(overrides: fakes.overrides);
  });
  tearDown(() => fakes.dispose());

  // Keeps the autoDispose chain `todayWordsProvider` reads
  // (`currentLearningDataProvider` -> `authUserProvider`) alive across the
  // async gap below — matches `learning_providers_test.dart`'s own
  // `keepAlive()` convention. Called AFTER seeding progress rows (never in
  // `setUp`): `LearningDataController.build()` reads the repositories once,
  // so listening before they are seeded would freeze an empty snapshot.
  void keepLearningDataAlive() =>
      container.listen(currentLearningDataProvider, (_, _) {});

  test('returns only due entries, earliest due first, capped at 3', () async {
    final due1 = fakes.content.words[0];
    final due2 = fakes.content.words[1];
    final due3 = fakes.content.words[2];
    final due4 = fakes.content.words[3];
    final notDue = fakes.content.words[4];
    // `fakes.clock` is fixed at 2026-09-13 (`day(13)`): every `nextDueOn`
    // below must be on or before it to count as due at all.
    await fakes.progress.saveProgress(
      buildProgress(wordId: due2.id, nextDueOn: day(10)),
    );
    await fakes.progress.saveProgress(
      buildProgress(wordId: due1.id, nextDueOn: day(9)),
    );
    await fakes.progress.saveProgress(
      buildProgress(wordId: due3.id, nextDueOn: day(11)),
    );
    await fakes.progress.saveProgress(
      buildProgress(wordId: due4.id, nextDueOn: day(1)),
    );
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: notDue.id,
        state: WordState.tuya,
        nextDueOn: day(30),
      ),
    );
    keepLearningDataAlive();

    final result = await container.read(todayWordsProvider.future);

    expect(result.map((e) => e.word.id).toList(), [due4.id, due1.id, due2.id]);
  });

  test('no due words -> empty list, never a crash', () async {
    keepLearningDataAlive();
    final result = await container.read(todayWordsProvider.future);

    expect(result, isEmpty);
  });
}
