import 'package:flui/shared/layout/section_rhythm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sectionRhythm', () {
    test('breaks a long page with a full-bleed green plate', () {
      expect(sectionRhythm(3), [
        SectionTone.cream,
        SectionTone.green,
        SectionTone.cream,
      ]);
    });

    test('never puts three cream sections in a row', () {
      final tones = sectionRhythm(24);
      var run = 0;
      for (final tone in tones) {
        run = tone == SectionTone.cream ? run + 1 : 0;
        expect(run, lessThanOrEqualTo(maxCreamRun));
      }
    });

    test('a page always opens on cream', () {
      expect(sectionToneAt(0), SectionTone.cream);
    });

    test('an empty page has no sections', () {
      expect(sectionRhythm(0), isEmpty);
    });
  });
}
