import 'package:flui/core/error/failure.dart';
import 'package:flui/features/themes/data/dtos/theme_dto.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/themes/data/fake_theme_repository.dart';
import 'package:flui/features/themes/data/supabase_theme_repository.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

Map<String, Object?> themeRow() => {
  'id': 't1',
  'slug': 'reuniones',
  'family': 'trabajo',
  'name': 'Reuniones',
  'tagline': 'Que se note que estabas ahí.',
  'jtbd': 'Quiero intervenir en una reunión y que se entienda a la primera.',
  'content_type': 'word_driven',
  'status': 'live',
  'sort_order': 1,
};

void main() {
  group('ThemeDto', () {
    test('maps a themes row to a Theme', () {
      final theme = ThemeDto.fromJson(themeRow()).toDomain();

      expect(theme.id, 't1');
      expect(theme.family, ThemeFamily.trabajo);
      expect(theme.contentType, ThemeContentType.wordDriven);
      expect(theme.status, ThemeStatus.live);
      expect(theme.isOffered, isTrue);
    });

    test('maps the two other content types', () {
      for (final (raw, expected) in [
        ('expression_driven', ThemeContentType.expressionDriven),
        ('mixed', ThemeContentType.mixed),
      ]) {
        final row = themeRow()..['content_type'] = raw;
        expect(ThemeDto.fromJson(row).toDomain().contentType, expected);
      }
    });

    test('a theme without content yet is not offered', () {
      final row = themeRow()..['status'] = 'soon';

      expect(ThemeDto.fromJson(row).toDomain().isOffered, isFalse);
    });

    test('selects every column the mapper reads', () {
      for (final column in [
        'slug',
        'family',
        'tagline',
        'jtbd',
        'content_type',
        'status',
        'sort_order',
      ]) {
        expect(ThemeDto.columns, contains(column));
      }
    });
  });

  group('SupabaseThemeRepository', () {
    test('selects published themes in catalog order', () async {
      final recorder = SupabaseRecorder(respond: (_) => [themeRow()]);
      addTearDown(recorder.dispose);

      final result = await SupabaseThemeRepository(recorder.client)
          .fetchThemes();

      expect(result.valueOrNull!.single.slug, 'reuniones');
      final url = recorder.last.url;
      expect(url.path, '/rest/v1/themes');
      expect(url.queryParameters['published'], 'eq.true');
      expect(url.queryParameters['order'], 'sort_order.asc.nullslast');
    });

    test('maps transport errors to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseThemeRepository(recorder.client)
          .fetchThemes();

      expect(result.failureOrNull, const NetworkFailure());
    });
  });

  group('FakeThemeRepository', () {
    test('serves the 16 seeded themes in order', () async {
      final result = await FakeThemeRepository().fetchThemes();

      final themes = result.valueOrNull!;
      expect(themes, hasLength(16));
      expect(themes.first.slug, 'reuniones');
      expect(themes.map((t) => t.sortOrder), List.generate(16, (i) => i + 1));
    });

    test('returns a queued failure once', () async {
      final repository = FakeThemeRepository()
        ..nextFailure = const NetworkFailure();

      expect((await repository.fetchThemes()).isOk, isFalse);
      expect((await repository.fetchThemes()).isOk, isTrue);
    });
  });

  group('the fake backend mirrors supabase/seed_themes.sql', () {
    test('every seed word carries between 1 and 3 themes', () {
      for (final word in seedWordsWithThemes) {
        expect(
          word.themeIds.length,
          inInclusiveRange(1, 3),
          reason: '${word.slug} must carry 1-3 themes',
        );
      }
    });

    test('tags every seed word and no word the seed does not have', () {
      expect(
        seedWordThemeSlugs.keys.toSet(),
        seedWords.map((word) => word.slug).toSet(),
      );
    });

    test('every tag points at a theme of the taxonomy', () {
      // The full 28-theme taxonomy, not just the 16 offered today: content
      // authors tag words with the twelve unpublished recombination themes
      // ahead of their own launch (GATE.md, content/themes.yml).
      final slugs = {
        for (final theme in [...seedThemes, ...unpublishedSeedThemes])
          theme.slug,
      };

      for (final entry in seedWordThemeSlugs.entries) {
        expect(slugs, containsAll(entry.value), reason: entry.key);
      }
    });

    test('no theme is live without a word behind it', () {
      final tagged = {for (final slugs in seedWordThemeSlugs.values) ...slugs};

      for (final theme in seedThemes) {
        if (!theme.isOffered) continue;
        expect(tagged, contains(theme.slug), reason: theme.slug);
      }
    });

    test('the semantic set groups the two ends of one axis', () {
      final tagged = [
        for (final word in seedWordsWithThemes)
          if (word.semanticSetId == 'fuerza-de-la-afirmacion') word.slug,
      ];

      expect(tagged, unorderedEquals(['contundente', 'matizar']));
    });

    test('leaves the generated word fixture untouched', () {
      // seed_content.dart is generated from supabase/seed.sql and proven
      // byte-identical by tool/seed_fixture_check.dart, so the themes are
      // layered on top instead of edited into it.
      expect(seedWords.every((word) => word.themeIds.isEmpty), isTrue);
      expect(seedWords.every((word) => word.semanticSetId == null), isTrue);
      expect(seedWordsWithThemes, hasLength(seedWords.length));
    });
  });
}
