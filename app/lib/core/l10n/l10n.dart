import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:flui/core/l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
