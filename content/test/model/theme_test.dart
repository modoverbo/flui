import 'dart:io';

import 'package:content/src/model/theme.dart';
import 'package:test/test.dart';

void main() {
  final taxonomy = ThemeTaxonomy.parse(
    File('themes.yml').readAsStringSync(),
  );

  test('ships the 16 launch themes', () {
    expect(taxonomy.themes, hasLength(16));
  });

  test('every theme has a unique slug and a unique sort order', () {
    expect(taxonomy.themes.map((t) => t.slug).toSet(), hasLength(16));
    expect(taxonomy.themes.map((t) => t.sortOrder).toSet(), hasLength(16));
  });

  test('sort orders run 1..16 without gaps', () {
    final orders = taxonomy.themes.map((t) => t.sortOrder).toList()..sort();
    expect(orders, List<int>.generate(16, (i) => i + 1));
  });

  test('every theme belongs to a known family', () {
    for (final theme in taxonomy.themes) {
      expect(themeFamilies, contains(theme.family));
    }
  });

  test('every theme declares a content type', () {
    for (final theme in taxonomy.themes) {
      expect(themeContentTypes, contains(theme.contentType));
    }
  });

  test('every theme carries Spanish copy', () {
    for (final theme in taxonomy.themes) {
      expect(theme.name, isNotEmpty, reason: theme.slug);
      expect(theme.tagline, isNotEmpty, reason: theme.slug);
      expect(theme.jtbd, isNotEmpty, reason: theme.slug);
    }
  });

  test('contains the slugs named by the launch plan', () {
    expect(
      taxonomy.slugs,
      containsAll(<String>[
        'reuniones',
        'presentaciones-oratoria',
        'entrevistas',
        'negociacion',
        'liderazgo-feedback',
        'conflicto-desacuerdo',
        'correos-mensajes',
        'redaccion-ejecutiva',
        'persuasion-storytelling',
        'conversaciones-dificiles',
        'matices-precision',
        'conectores-estructura',
        'paronimos',
        'elogio-reconocimiento',
        'decir-que-no',
        'conversacion-cotidiana',
      ]),
    );
  });

  test('lookup by slug returns null for an unknown theme', () {
    expect(taxonomy.bySlug('reuniones'), isNotNull);
    expect(taxonomy.bySlug('no-existe'), isNull);
  });
}
