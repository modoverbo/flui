import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand mark master is vector artwork based on the selected concept', () {
    final svg = File('assets/brand/flui_brand_mark.svg').readAsStringSync();

    expect(svg, contains('<svg'));
    expect(svg, contains('#151426'));
    expect(svg, contains('#0B3D34'));
    expect(svg, contains('#FFD60A'));
    expect(svg, contains('flui-brand-wave'));
    expect(svg, contains('<title>flui'));
  });

  test('web and native icon outputs keep their platform dimensions', () {
    final expectedSizes = {
      'web/favicon.png': 32,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
      'web/icons/apple-touch-icon.png': 180,
      'assets/brand/launcher/flui_launcher_icon.png': 1024,
      'assets/brand/launcher/flui_launcher_foreground.png': 1024,
    };

    for (final entry in expectedSizes.entries) {
      final png = ByteData.sublistView(File(entry.key).readAsBytesSync());
      expect(png.getUint32(16), entry.value, reason: entry.key);
      expect(png.getUint32(20), entry.value, reason: entry.key);
    }
  });
}
