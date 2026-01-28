import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

export 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Extension to easily access localizations from BuildContext
extension AppLocalizationsX on BuildContext {
  /// Get the AppLocalizations instance
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
