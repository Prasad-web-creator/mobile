import 'package:claimsupport/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:claimsupport/l10n/app_localizations.dart';

extension BuildContextLocalization on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(Locale(Localizations.maybeLocaleOf(this)?.languageCode == 'ta' ? 'ta' : 'en'));
}
