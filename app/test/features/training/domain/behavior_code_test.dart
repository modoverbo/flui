import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BehaviorCode', () {
    test('every code carries a non-empty snake_case wireCode', () {
      final wireCodePattern = RegExp(r'^[a-z]+(_[a-z]+)*$');
      for (final code in BehaviorCode.values) {
        expect(
          code.wireCode,
          matches(wireCodePattern),
          reason: '${code.name} has an invalid wireCode "${code.wireCode}"',
        );
      }
    });

    test('wireCodes are unique (closed, unambiguous catalog)', () {
      final wireCodes = BehaviorCode.values.map((c) => c.wireCode).toSet();
      expect(wireCodes, hasLength(BehaviorCode.values.length));
    });

    test('thinking codes are AI-observed and area-tagged thinking', () {
      const thinking = [
        BehaviorCode.mainPointLate,
        BehaviorCode.noClearStructure,
        BehaviorCode.missingExample,
        BehaviorCode.noClosing,
        BehaviorCode.clearMainPoint,
        BehaviorCode.orderedIdeas,
      ];
      for (final code in thinking) {
        expect(code.area, SkillArea.thinking);
      }
      expect(
        thinking.where((c) => c.polarity == Polarity.opportunity),
        hasLength(4),
      );
      expect(
        thinking.where((c) => c.polarity == Polarity.strength),
        hasLength(2),
      );
    });

    test('language codes are area-tagged language', () {
      const language = [
        BehaviorCode.vagueWord,
        BehaviorCode.repeatedWord,
        BehaviorCode.weakConnector,
        BehaviorCode.registerMismatch,
        BehaviorCode.preciseWord,
        BehaviorCode.variedVocabulary,
      ];
      for (final code in language) {
        expect(code.area, SkillArea.language);
      }
    });

    test('voice/fluency codes split pace+volume (voice) from pauses+fillers '
        '(fluency)', () {
      const voice = [
        BehaviorCode.paceFast,
        BehaviorCode.paceSlow,
        BehaviorCode.volumeUnstable,
        BehaviorCode.steadyPace,
        BehaviorCode.steadyVolume,
      ];
      const fluency = [
        BehaviorCode.longPauses,
        BehaviorCode.fillerHeavy,
        BehaviorCode.controlledFillers,
        BehaviorCode.usefulPauses,
      ];
      for (final code in voice) {
        expect(code.area, SkillArea.voice);
      }
      for (final code in fluency) {
        expect(code.area, SkillArea.fluency);
      }
    });

    test('fromWireCode resolves a known code and rejects an unknown one', () {
      expect(
        BehaviorCode.fromWireCode('main_point_late'),
        BehaviorCode.mainPointLate,
      );
      expect(BehaviorCode.fromWireCode('not_a_real_code'), isNull);
    });
  });
}
