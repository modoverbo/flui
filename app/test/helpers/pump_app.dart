import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

extension PumpFlui on WidgetTester {
  /// Pumps [child] inside the flui theme, Spanish localizations and a
  /// provider scope (automatic retry disabled).
  Future<void> pumpFlui(
    Widget child, {
    List<Override> overrides = const [],
    Size? surfaceSize,
    bool disableAnimations = true,
  }) async {
    if (surfaceSize != null) {
      await binding.setSurfaceSize(surfaceSize);
      addTearDown(() => binding.setSurfaceSize(null));
    }
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          theme: FluiTheme.light(),
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await pump();
  }
}

/// A [FluiTextField] by the label the user typed in the ARB file; the field
/// renders it in caps.
Finder fluiField(String label) =>
    find.widgetWithText(FluiTextField, FluiTypeScale.labelText(label));

/// Spanish strings for assertions.
final AppLocalizations l10nEs = lookupAppLocalizations(const Locale('es'));
