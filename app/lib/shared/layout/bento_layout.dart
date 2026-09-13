import 'package:material_ui/material_ui.dart';

/// How much of the bento grid a tile takes.
enum BentoSpan {
  /// One cell.
  small(1, 1),

  /// The full width, one cell tall.
  wide(2, 1),

  /// The full width, two cells tall: the anchor of the grid.
  large(2, 2);

  new(this.columns, this.rows);

  final int columns;
  final int rows;
}

/// Where one tile ended up in the grid.
@immutable
final class BentoPlacement {
  const new({required this.span, required this.column, required this.row});

  final BentoSpan span;
  final int column;
  final int row;

  int get endRow => row + span.rows;

  @override
  bool operator ==(Object other) =>
      other is BentoPlacement &&
      other.span == span &&
      other.column == column &&
      other.row == row;

  @override
  int get hashCode => Object.hash(span, column, row);

  @override
  String toString() => 'BentoPlacement($span, c$column, r$row)';
}

/// Packs [spans] into a [columns]-wide grid, keeping the author's order.
///
/// Full-width tiles start a new row; single tiles fill the first hole, so a
/// 2x2 anchor next to two 1x1s reads as one composition instead of a list.
List<BentoPlacement> packBento(List<BentoSpan> spans, {int columns = 2}) {
  assert(columns > 0, 'a grid needs at least one column');
  final occupied = <int, List<bool>>{};
  List<bool> rowAt(int row) =>
      occupied.putIfAbsent(row, () => List.filled(columns, false));

  bool fits(int row, int column, BentoSpan span) {
    if (column + span.columns > columns) return false;
    for (var r = row; r < row + span.rows; r++) {
      for (var c = column; c < column + span.columns; c++) {
        if (rowAt(r)[c]) return false;
      }
    }
    return true;
  }

  void occupy(int row, int column, BentoSpan span) {
    for (var r = row; r < row + span.rows; r++) {
      for (var c = column; c < column + span.columns; c++) {
        rowAt(r)[c] = true;
      }
    }
  }

  final placements = <BentoPlacement>[];
  for (final span in spans) {
    var row = 0;
    var placed = false;
    while (!placed) {
      for (var column = 0; column < columns && !placed; column++) {
        if (!fits(row, column, span)) continue;
        occupy(row, column, span);
        placements.add(BentoPlacement(span: span, column: column, row: row));
        placed = true;
      }
      if (!placed) row++;
    }
  }
  return placements;
}

/// Rows the packed grid needs.
int bentoRowCount(List<BentoPlacement> placements) => placements.fold(
  0,
  (rows, placement) => placement.endRow > rows ? placement.endRow : rows,
);
