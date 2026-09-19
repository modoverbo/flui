import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('StickyCtaDock.contentMinHeight', () {
    test('a normal viewport subtracts the reserved dock height', () {
      const constraints = BoxConstraints(maxHeight: 800);

      expect(
        StickyCtaDock.contentMinHeight(constraints),
        800 - StickyCtaDock.reservedHeight,
      );
    });

    test('a viewport shorter than the dock never goes negative', () {
      const constraints = BoxConstraints(maxHeight: 100);

      expect(StickyCtaDock.contentMinHeight(constraints), 0);
    });

    test('an infinite maxHeight resolves to zero, not infinity', () {
      const constraints = BoxConstraints();

      expect(StickyCtaDock.contentMinHeight(constraints), 0);
    });
  });
}
