import 'package:flui/shared/layout/bento_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('packBento', () {
    test('anchors a 2x2 tile and fills the next rows with singles', () {
      final placements = packBento(const [
        BentoSpan.large,
        BentoSpan.small,
        BentoSpan.small,
        BentoSpan.wide,
      ]);

      expect(placements, const [
        BentoPlacement(span: BentoSpan.large, column: 0, row: 0),
        BentoPlacement(span: BentoSpan.small, column: 0, row: 2),
        BentoPlacement(span: BentoSpan.small, column: 1, row: 2),
        BentoPlacement(span: BentoSpan.wide, column: 0, row: 3),
      ]);
      expect(bentoRowCount(placements), 4);
    });

    test('a single tile fills the hole a previous single left', () {
      final placements = packBento(const [
        BentoSpan.small,
        BentoSpan.small,
        BentoSpan.small,
      ]);

      expect(placements.map((p) => (p.column, p.row)), [
        (0, 0),
        (1, 0),
        (0, 1),
      ]);
    });

    test('a full-width tile never shares a row', () {
      final placements = packBento(const [
        BentoSpan.small,
        BentoSpan.wide,
        BentoSpan.small,
      ]);

      expect(
        placements[0],
        const BentoPlacement(span: BentoSpan.small, column: 0, row: 0),
      );
      expect(
        placements[1],
        const BentoPlacement(span: BentoSpan.wide, column: 0, row: 1),
      );
      expect(
        placements[2],
        const BentoPlacement(span: BentoSpan.small, column: 1, row: 0),
      );
    });

    test('tiles never overlap', () {
      final placements = packBento(const [
        BentoSpan.large,
        BentoSpan.small,
        BentoSpan.small,
        BentoSpan.small,
        BentoSpan.wide,
        BentoSpan.small,
        BentoSpan.large,
      ]);

      final cells = <(int, int)>{};
      for (final placement in placements) {
        for (var r = placement.row; r < placement.endRow; r++) {
          for (
            var c = placement.column;
            c < placement.column + placement.span.columns;
            c++
          ) {
            expect(cells.add((c, r)), isTrue, reason: 'overlap at ($c, $r)');
          }
        }
      }
    });

    test('keeps every tile inside the grid', () {
      final placements = packBento(const [
        BentoSpan.small,
        BentoSpan.large,
        BentoSpan.wide,
      ]);

      for (final placement in placements) {
        expect(placement.column + placement.span.columns, lessThanOrEqualTo(2));
        expect(placement.column, greaterThanOrEqualTo(0));
      }
    });

    test('an empty grid has no rows', () {
      expect(packBento(const []), isEmpty);
      expect(bentoRowCount(const []), 0);
    });

    test('honours a wider grid', () {
      final placements = packBento(const [
        BentoSpan.small,
        BentoSpan.small,
        BentoSpan.small,
      ], columns: 3);

      expect(placements.map((p) => (p.column, p.row)), [
        (0, 0),
        (1, 0),
        (2, 0),
      ]);
    });
  });
}
