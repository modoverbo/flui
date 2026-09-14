import 'package:content/src/corpus/cooccurrence.dart';
import 'package:test/test.dart';

void main() {
  const wordsTxt =
      '1\tplantear\t50\n2\ttema\t90\n3\thacer\t400\n4\tsartén\t7\n';
  const coTxt = '1\t2\t9\t120.5\n3\t2\t20\t300.0\n1\t4\t2\t3.1\nbad line\n';

  group('parseWordIds', () {
    test('maps the Leipzig numeric ids onto surfaces', () {
      expect(parseWordIds(wordsTxt), {
        1: 'plantear',
        2: 'tema',
        3: 'hacer',
        4: 'sartén',
      });
    });
  });

  group('streamCooccurrences', () {
    test('yields folded pairs with their significance', () {
      final seen = <String>[];
      streamCooccurrences(
        words: parseWordIds(wordsTxt),
        cooccurrences: coTxt,
        onPair: (a, b, sig) => seen.add('$a|$b|$sig'),
      );

      expect(seen, [
        'plantear|tema|120.5',
        'hacer|tema|300.0',
        'plantear|sarten|3.1',
      ]);
    });

    test('skips rows whose ids are unknown', () {
      var pairs = 0;
      streamCooccurrences(
        words: const {1: 'plantear'},
        cooccurrences: coTxt,
        onPair: (_, _, _) => pairs++,
      );

      expect(pairs, 0);
    });
  });

  group('EvidenceBuilder', () {
    EvidenceIndex build() {
      final builder = EvidenceBuilder(
        interesting: {'plantear', 'hacer'},
        groups: {
          'abstract': {'tema'},
          'physical': {'sarten'},
        },
      );
      streamCooccurrences(
        words: parseWordIds(wordsTxt),
        cooccurrences: coTxt,
        onPair: builder.add,
      );
      return builder.build();
    }

    test('accumulates significance per group', () {
      final index = build();

      expect(index.massOf('plantear', 'abstract'), closeTo(120.5, 1e-9));
      expect(index.massOf('plantear', 'physical'), closeTo(3.1, 1e-9));
      expect(index.massOf('hacer', 'abstract'), closeTo(300.0, 1e-9));
    });

    test('tracks the total mass of every interesting word', () {
      final index = build();

      expect(index.totalMassOf('plantear'), closeTo(123.6, 1e-9));
      expect(index.totalMassOf('tema'), 0);
    });

    test('reports a share of total mass', () {
      final index = build();

      expect(
        index.shareOf('plantear', 'abstract'),
        closeTo(120.5 / 123.6, 1e-9),
      );
      expect(index.shareOf('hacer', 'physical'), 0);
    });

    test('is 0 for a word it never saw', () {
      expect(build().shareOf('desir', 'abstract'), 0);
      expect(build().hasEvidence('desir'), isFalse);
      expect(build().hasEvidence('plantear'), isTrue);
    });

    test('ignores words outside the interesting set', () {
      final index = build();

      expect(index.hasEvidence('tema'), isFalse);
    });
  });

  group('baselines and lift', () {
    EvidenceIndex build() {
      final builder = EvidenceBuilder(
        interesting: {'plantear', 'hacer'},
        groups: {
          'abstract': {'tema'},
          'physical': {'sarten'},
        },
      );
      streamCooccurrences(
        words: parseWordIds(wordsTxt),
        cooccurrences: coTxt,
        onPair: builder.add,
      );
      return builder.build();
    }

    test('a baseline is the share the whole population gives a group', () {
      // 420.5 of 423.6 total mass falls on "tema".
      expect(build().baselineShareOf('abstract'), closeTo(420.5 / 423.6, 1e-9));
      expect(build().baselineShareOf('physical'), closeTo(3.1 / 423.6, 1e-9));
    });

    test('lift is 1 when a word is exactly average', () {
      final index = build();
      expect(index.liftOf('hacer', 'abstract'), greaterThan(1));
      expect(index.liftOf('plantear', 'physical'), greaterThan(1));
    });

    test('lift is 0 for a word with no mass at all', () {
      expect(build().liftOf('desir', 'abstract'), 0);
    });

    test('lift is 0 when the group is empty everywhere', () {
      final builder = EvidenceBuilder(
        interesting: {'plantear'},
        groups: {'nothing': <String>{}},
      );
      streamCooccurrences(
        words: parseWordIds(wordsTxt),
        cooccurrences: coTxt,
        onPair: builder.add,
      );
      expect(builder.build().liftOf('plantear', 'nothing'), 0);
    });
  });

  group('topCoOccurring', () {
    test('keeps the strongest partners of a seed set', () {
      final builder = CoOccurrenceCollector(
        seeds: {'hacer'},
        keep: (word) => word != 'hacer',
      );
      streamCooccurrences(
        words: parseWordIds(wordsTxt),
        cooccurrences: coTxt,
        onPair: builder.add,
      );

      expect(builder.top(1), {'tema'});
      expect(builder.top(10), {'tema'});
    });

    test('returns nothing when no seed occurs', () {
      final builder = CoOccurrenceCollector(
        seeds: {'zanjar'},
        keep: (_) => true,
      );
      streamCooccurrences(
        words: parseWordIds(wordsTxt),
        cooccurrences: coTxt,
        onPair: builder.add,
      );

      expect(builder.top(5), isEmpty);
    });
  });
}
