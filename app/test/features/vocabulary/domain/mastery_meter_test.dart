import 'package:flui/features/vocabulary/domain/mastery_meter.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  group('MasteryMeter', () {
    test('a word met today already shows one rung, never zero', () {
      final progress = buildProgress(wordId: 'w', state: WordState.nueva);

      expect(MasteryMeter.countFor(progress), 1);
      expect(MasteryMeter.reached(progress), {MasteryStep.discovered});
      expect(MasteryMeter.nextFor(progress), MasteryStep.practiced);
    });

    test('each criterion lights its own rung', () {
      final progress = buildProgress(
        wordId: 'w',
        formRecallDone: true,
        productionDone: true,
      );

      expect(MasteryMeter.reached(progress), {
        MasteryStep.discovered,
        MasteryStep.practiced,
        MasteryStep.recall,
        MasteryStep.production,
      });
      expect(MasteryMeter.countFor(progress), 4);
      expect(MasteryMeter.nextFor(progress), MasteryStep.owned);
    });

    test('recall and production count before the word is owned', () {
      final progress = buildProgress(
        wordId: 'w',
        state: WordState.nueva,
        formRecallDone: true,
      );

      expect(MasteryMeter.reached(progress), {
        MasteryStep.discovered,
        MasteryStep.recall,
      });
      expect(MasteryMeter.nextFor(progress), MasteryStep.practiced);
    });

    test('a tuya word fills the meter', () {
      final progress = buildProgress(
        wordId: 'w',
        state: WordState.tuya,
        formRecallDone: true,
        productionDone: true,
      );

      expect(MasteryMeter.countFor(progress), MasteryMeter.total);
      expect(MasteryMeter.nextFor(progress), isNull);
    });
  });
}
