import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers bundled third-party licenses (fonts and the logo source) so they
/// appear in the license page next to the package licenses.
void registerBundledLicenses({AssetBundle? bundle}) {
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final (package, path) in bundledLicenses) {
      yield LicenseEntryWithLineBreaks([
        package,
      ], await assets.loadString(path));
    }
  });
}

const bundledLicenses = [
  ('Plus Jakarta Sans (font)', 'assets/fonts/plus_jakarta_sans/OFL.txt'),
  ('Inter (font)', 'assets/fonts/inter/OFL.txt'),
  (
    'Tabler Icons (flui symbol source)',
    'assets/brand/LICENSE-tabler-icons.txt',
  ),
];
