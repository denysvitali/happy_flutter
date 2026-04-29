// Re-exports the generated AppLocalizations class and adds the
// BuildContext.l10n convenience accessor.
//
// All 85 files in the codebase import this path; by making it a
// re-export we switch them all to the generated class without
// touching every import site.
import 'package:flutter/widgets.dart';

import '../../l10n_generated/app_localizations.dart';

export '../../l10n_generated/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
