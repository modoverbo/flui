import 'dart:io';

import 'package:content/src/model/theme.dart';
import 'package:content/src/sql/seed_sql_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The catalogue the database is seeded from. Its copy is `themes.yml`'s copy;
/// the rows add only the offer (`status`, `published`) and the stable uuids.
final String seedThemesPath = p.normalize(
  p.join(Directory.current.path, '..', 'supabase', 'seed_themes.sql'),
);

const _launchSlugs = <String>[
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
];

const _expansionSlugs = <String>[
  'ventas',
  'networking',
  'redes-sociales',
  'docencia',
  'medios-entrevistas',
  'humor',
  'citas',
  'amistad',
  'small-talk',
  'familia-crianza',
  'empatia-escucha',
  'pedir-disculparse',
];

void main() {
  final taxonomy = ThemeTaxonomy.parse(
    File('themes.yml').readAsStringSync(),
  );

  test('ships the 16 launch themes and the 12 that recombine them', () {
    expect(taxonomy.themes, hasLength(28));
  });

  test('every theme has a unique slug and a unique sort order', () {
    expect(taxonomy.themes.map((t) => t.slug).toSet(), hasLength(28));
    expect(taxonomy.themes.map((t) => t.sortOrder).toSet(), hasLength(28));
  });

  test('sort orders run 1..28 without gaps', () {
    final orders = taxonomy.themes.map((t) => t.sortOrder).toList()..sort();
    expect(orders, List<int>.generate(28, (i) => i + 1));
  });

  test('the launch themes keep the first 16 places', () {
    final launch = taxonomy.themes.where((t) => t.sortOrder <= 16);
    expect(launch.map((t) => t.slug), unorderedEquals(_launchSlugs));
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
    expect(taxonomy.slugs, containsAll(_launchSlugs));
  });

  test('contains the twelve themes that recombine the same words', () {
    expect(taxonomy.slugs, containsAll(_expansionSlugs));
  });

  test('lookup by slug returns null for an unknown theme', () {
    expect(taxonomy.bySlug('reuniones'), isNotNull);
    expect(taxonomy.bySlug('no-existe'), isNull);
  });

  group('supabase/seed_themes.sql', () {
    final rows = parseSeedRows(
      File(seedThemesPath).readAsStringSync(),
    )['themes']!;

    test('seeds exactly the themes of the taxonomy', () {
      expect(
        rows.map((row) => row['slug']),
        unorderedEquals(taxonomy.slugs),
      );
    });

    test('copies every field of content/themes.yml verbatim', () {
      for (final row in rows) {
        final slug = row['slug']! as String;
        final theme = taxonomy.bySlug(slug);
        expect(theme, isNotNull, reason: slug);
        expect(row['family'], theme!.family, reason: slug);
        expect(row['name'], theme.name, reason: slug);
        expect(row['tagline'], theme.tagline, reason: slug);
        expect(row['jtbd'], theme.jtbd, reason: slug);
        expect(row['content_type'], theme.contentType, reason: slug);
        expect(row['sort_order'], theme.sortOrder, reason: slug);
      }
    });

    test('never offers a theme that has no words behind it yet', () {
      final unpublished = [
        for (final row in rows)
          if (row['published'] == false) row['slug'],
      ];
      expect(unpublished, unorderedEquals(_expansionSlugs));
      for (final row in rows) {
        if (row['published'] == false) {
          expect(row['status'], 'soon', reason: row['slug']! as String);
        }
      }
    });
  });
}
