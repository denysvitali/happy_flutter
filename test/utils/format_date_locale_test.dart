import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/utils.dart';
import 'package:happy_flutter/l10n_generated/app_localizations_en.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locale contract for the shared date helpers.
///
/// Two things are pinned here:
///  1. dates render in the order of the *formatting* locale, not a hardcoded
///     US `M/d/yyyy`;
///  2. a locale intl cannot serve degrades instead of throwing. intl signals
///     that with an `ArgumentError` — a subtype of `Error`, NOT `Exception` —
///     once symbol data is initialized (and `LocaleDataException` before),
///     so a narrow `on Exception` catch would not hold.
void main() {
  final date = DateTime(2026, 7, 31);

  setUpAll(() async {
    await initializeDateFormatting();
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  group('formatShortDate', () {
    test('uses the requested locale order', () {
      expect(formatShortDate(date, locale: 'en_US'), '7/31/2026');
      expect(formatShortDate(date, locale: 'de'), '31.7.2026');
      expect(formatShortDate(date, locale: 'en_GB'), '31/07/2026');
    });

    test('falls back to Intl.defaultLocale when no locale is passed', () {
      Intl.defaultLocale = 'de_DE';
      expect(formatShortDate(date), '31.7.2026');
      Intl.defaultLocale = 'en_US';
      expect(formatShortDate(date), '7/31/2026');
    });

    test('unknown locale degrades instead of throwing', () {
      expect(
        () => formatShortDate(date, locale: 'zz_ZZ_NOPE'),
        returnsNormally,
      );
      expect(formatShortDate(date, locale: 'zz_ZZ_NOPE'), '7/31/2026');
    });

    test('unknown Intl.defaultLocale degrades instead of throwing', () {
      Intl.defaultLocale = 'zz_ZZ_NOPE';
      expect(() => formatShortDate(date), returnsNormally);
      expect(formatShortDate(date), '7/31/2026');
    });
  });

  group('formatShortDayMonth', () {
    test('uses the requested locale order', () {
      expect(formatShortDayMonth(date, locale: 'en_US'), '7/31');
      expect(formatShortDayMonth(date, locale: 'de'), '31.7.');
    });

    test('unknown locale degrades instead of throwing', () {
      expect(
        () => formatShortDayMonth(date, locale: 'zz_ZZ_NOPE'),
        returnsNormally,
      );
      expect(formatShortDayMonth(date, locale: 'zz_ZZ_NOPE'), '7/31');
    });
  });

  group('formatTimestamp', () {
    test('absolute form follows the locale', () {
      final ms = date.millisecondsSinceEpoch;
      expect(formatTimestamp(ms, locale: 'de'), '31.7.2026');
      expect(formatTimestamp(ms, locale: 'en_US'), '7/31/2026');
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 8, 10, 12);

    test('older than a week falls back to the locale date', () {
      expect(
        formatRelativeTime(date, now: now, locale: 'de'),
        '31.7.2026',
      );
      expect(
        formatRelativeTime(date, now: now, locale: 'en_US'),
        '7/31/2026',
      );
    });

    test('explicit absoluteFallback still wins', () {
      expect(
        formatRelativeTime(
          date,
          now: now,
          locale: 'de',
          absoluteFallback: formatShortDayMonth,
        ),
        '31.7.',
      );
    });

    test('relative buckets are localized through l10n', () {
      final l10n = AppLocalizationsEn();
      expect(
        formatRelativeTime(
          now.subtract(const Duration(seconds: 5)),
          now: now,
          l10n: l10n,
        ),
        l10n.relativeJustNow,
      );
      expect(
        formatRelativeTime(
          now.subtract(const Duration(minutes: 5)),
          now: now,
          l10n: l10n,
        ),
        l10n.relativeMinutesAgo(5),
      );
      expect(
        formatRelativeTime(
          now.subtract(const Duration(hours: 3)),
          now: now,
          compact: true,
          l10n: l10n,
        ),
        l10n.relativeHoursCompact(3),
      );
      expect(
        formatRelativeTime(
          now.subtract(const Duration(days: 3)),
          now: now,
          l10n: l10n,
        ),
        l10n.relativeDaysAgo(3),
      );
      expect(
        formatRelativeTime(
          now.subtract(const Duration(hours: 25)),
          now: now,
          useYesterdayLabel: true,
          l10n: l10n,
        ),
        l10n.relativeYesterday,
      );
    });

    test('without l10n the buckets keep their English defaults', () {
      // Not a locale contract — just proves the argument is optional for the
      // context-free call sites that cannot reach an AppLocalizations.
      expect(
        formatRelativeTime(
          now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        isNotEmpty,
      );
    });

    test('small future skew still reads as just now', () {
      expect(
        formatRelativeTime(
          now.add(const Duration(seconds: 20)),
          now: now,
        ),
        'Just now',
      );
    });

    test('large future timestamps are not pinned to just now', () {
      expect(
        formatRelativeTime(
          now.add(const Duration(hours: 2)),
          now: now,
          locale: 'en_US',
        ),
        '8/10/2026',
      );
    });
  });
}
