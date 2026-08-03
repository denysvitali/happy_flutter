import 'package:intl/intl.dart';

import '../i18n/app_localizations.dart';

extension DateTimeExtensions on DateTime {
  /// Format as HH:mm:ss.SSS time string
  String toIsoTimeString() {
    final time = DateFormat('HH:mm:ss.SSS').format(this);
    return time;
  }

  /// Format as HH:mm:ss time string
  String toTimeString() {
    final formatter = DateFormat.Hms();
    return formatter.format(this);
  }

  /// Format as ISO8601 date string
  String toIsoDateString() {
    final date = DateFormat('yyyy-MM-dd').format(this);
    return date;
  }

  /// Format as "Today at HH:mm", "Yesterday at HH:mm", or a
  /// locale-aware full date+time string.
  ///
  /// [locale] (e.g. 'en', 'de', 'fr') defaults to [Intl.defaultLocale], which
  /// `main()` seeds from the platform locale — so the date order follows the
  /// device even though the UI language is English.
  ///
  /// Pass [l10n] to localize the "Today"/"Yesterday" wording; without it the
  /// English strings are used.
  ///
  /// Never throws on an unknown or not-yet-initialized locale: intl signals
  /// that with an `ArgumentError` (an `Error`, not an `Exception`) or a
  /// `LocaleDataException`, both of which degrade to `en_US` here.
  String toRelativeTimeString({String? locale, AppLocalizations? l10n}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisDate = DateTime(year, month, day);

    final time = _format(DateFormat.Hm, locale);

    if (thisDate == today) {
      return l10n?.dateTimeToday(time) ?? 'Today at $time';
    } else if (thisDate == yesterday) {
      return l10n?.dateTimeYesterday(time) ?? 'Yesterday at $time';
    } else {
      final date = _format(DateFormat.yMMMd, locale);
      return '$date $time';
    }
  }

  String _format(DateFormat Function([String?]) build, String? locale) {
    try {
      return build(locale ?? Intl.defaultLocale).format(this);
    } catch (_) {
      // Deliberately catch-all — see the doc comment above.
      return build('en_US').format(this);
    }
  }
}
