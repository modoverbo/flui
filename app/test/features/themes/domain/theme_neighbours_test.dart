import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_neighbours.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final reuniones = buildTheme(slug: 'reuniones');
  final negociacion = buildTheme(slug: 'negociacion', sortOrder: 2);
  final matices = buildTheme(slug: 'matices', sortOrder: 3);
  final lejano = buildTheme(slug: 'lejano', sortOrder: 4);
  final themes = [reuniones, negociacion, matices, lejano];

  // reuniones shares three words with negociacion and one with matices.
  final catalog = [
    buildWord(id: 'zanjar', themeIds: ['reuniones', 'negociacion']),
    buildWord(
      id: 'concretar',
      sortOrder: 2,
      themeIds: ['reuniones', 'negociacion'],
    ),
    buildWord(
      id: 'sopesar',
      sortOrder: 3,
      themeIds: ['reuniones', 'negociacion'],
    ),
    buildWord(id: 'matizar', sortOrder: 4, themeIds: ['reuniones', 'matices']),
    buildWord(id: 'aparte', sortOrder: 5, themeIds: ['lejano']),
  ];

  group('ThemeNeighbours.nearest', () {
    test('orders neighbours by how many words they share', () {
      final neighbours = ThemeNeighbours.nearest(
        theme: reuniones,
        themes: themes,
        catalog: catalog,
      );

      expect(neighbours.map((t) => t.slug), ['negociacion', 'matices']);
    });

    test('a theme that shares nothing is not a neighbour', () {
      final neighbours = ThemeNeighbours.nearest(
        theme: reuniones,
        themes: themes,
        catalog: catalog,
      );

      expect(neighbours.map((t) => t.slug), isNot(contains('lejano')));
    });

    test('the theme is never its own neighbour', () {
      final neighbours = ThemeNeighbours.nearest(
        theme: reuniones,
        themes: themes,
        catalog: catalog,
      );

      expect(neighbours.map((t) => t.slug), isNot(contains('reuniones')));
    });

    test('a theme that is not live today is never a neighbour', () {
      final soon = buildTheme(
        slug: 'pronto',
        status: ThemeStatus.soon,
        sortOrder: 0,
      );
      final neighbours = ThemeNeighbours.nearest(
        theme: reuniones,
        themes: [...themes, soon],
        catalog: [
          ...catalog,
          buildWord(
            id: 'compartida',
            sortOrder: 6,
            themeIds: ['reuniones', 'pronto'],
          ),
        ],
      );

      expect(neighbours.map((t) => t.slug), isNot(contains('pronto')));
    });

    test('equal overlap breaks by catalog order', () {
      final a = buildTheme(slug: 'a', sortOrder: 7);
      final b = buildTheme(slug: 'b', sortOrder: 8);
      final neighbours = ThemeNeighbours.nearest(
        theme: reuniones,
        themes: [b, a, reuniones],
        catalog: [
          buildWord(themeIds: ['reuniones', 'a']),
          buildWord(id: 'w2', sortOrder: 2, themeIds: ['reuniones', 'b']),
        ],
      );

      expect(neighbours.map((t) => t.slug), ['a', 'b']);
    });

    test('an empty catalog has no neighbours', () {
      expect(
        ThemeNeighbours.nearest(
          theme: reuniones,
          themes: themes,
          catalog: const [],
        ),
        isEmpty,
      );
    });

    test('ids keeps the same order as nearest', () {
      expect(
        ThemeNeighbours.nearestIds(
          theme: reuniones,
          themes: themes,
          catalog: catalog,
        ),
        ['negociacion', 'matices'],
      );
    });
  });
}
