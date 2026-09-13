import 'dart:io';

import 'package:flui/app/licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled license files exist and are declared as assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final (_, path) in bundledLicenses) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(pubspec, contains(path));
    }
  });

  test('registers the font and logo licenses', () async {
    registerBundledLicenses();

    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }

    expect(packages, containsAll(['Plus Jakarta Sans (font)', 'Inter (font)']));
    expect(packages.any((name) => name.contains('Tabler')), isTrue);
  });
}
