import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/originality.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

class _RecordingFetcher implements SearchFetcher {
  _RecordingFetcher([this.hits = const []]);

  final List<SearchHit> hits;
  final List<String> queries = [];

  @override
  Future<List<SearchHit>> search(String query) async {
    queries.add(query);
    return hits;
  }
}

void main() {
  const probing = ValidationOptions(probeRae: true);

  test('does nothing unless --probe-rae is on', () async {
    final fetcher = _RecordingFetcher();
    final validator = RaeProbeValidator(fetcher);

    final issues = await validator.validateWordAsync(
      validWord(),
      contextOf([validWord()]),
    );

    expect(issues, isEmpty);
    expect(fetcher.queries, isEmpty);
  });

  test('probes two 6-grams per originality field, site restricted', () async {
    final fetcher = _RecordingFetcher();
    final validator = RaeProbeValidator(fetcher);

    await validator.validateWordAsync(
      validWord(),
      contextOf([validWord()], options: probing),
    );

    expect(fetcher.queries, hasLength(6));
    for (final query in fetcher.queries) {
      expect(query, contains('site:rae.es OR site:dle.rae.es'));
      expect(query, startsWith('"'));
    }
  });

  test('reports an exact hit as a blocking issue', () async {
    final gram = sixGrams(
      'Que se da cuenta rápido de lo que no es obvio y capta detalles que otros no ven.',
    ).first;
    final fetcher = _RecordingFetcher([
      SearchHit(
        url: 'https://dle.rae.es/perspicaz',
        snippet: 'dice: $gram, sin duda',
      ),
    ]);
    final validator = RaeProbeValidator(fetcher);

    final issues = await validator.validateWordAsync(
      validWord(),
      contextOf([validWord()], options: probing),
    );

    expect(issues, isNotEmpty);
    expect(issues.first.message, contains('dle.rae.es'));
  });

  test('ignores a hit whose snippet does not contain the gram', () async {
    final fetcher = _RecordingFetcher(const [
      SearchHit(
        url: 'https://dle.rae.es/perspicaz',
        snippet: 'otra cosa distinta',
      ),
    ]);
    final validator = RaeProbeValidator(fetcher);

    final issues = await validator.validateWordAsync(
      validWord(),
      contextOf([validWord()], options: probing),
    );

    expect(issues, isEmpty);
  });

  group('sixGrams', () {
    test('prefers grams dense in content words', () {
      final grams = sixGrams(
        'Que se da cuenta rápido de lo que no es obvio y capta detalles que otros no ven.',
      );
      expect(grams, hasLength(2));
      expect(grams.first.split(' '), hasLength(6));
      expect(grams.first, isNot(grams.last));
    });

    test('returns nothing for a text shorter than six words', () {
      expect(sixGrams('Solo cinco palabras aquí mismo'), isEmpty);
    });
  });
}
