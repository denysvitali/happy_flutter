import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/utils.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locale-correct date formatting.
///
/// `_shortDate` used to hardcode the US month/day/year order via string
/// interpolation, so every non-US locale got a wrong-order date. These tests
/// pin the ordering per locale.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  final date = DateTime(2026, 7, 31, 13, 45);

  group('formatShortDate', () {
    test('en_US orders month/day/year', () {
      expect(formatShortDate(date, locale: 'en_US'), '7/31/2026');
    });

    test('en_GB orders day/month/year', () {
      expect(formatShortDate(date, locale: 'en_GB'), '31/07/2026');
    });

    test('de orders day.month.year', () {
      expect(formatShortDate(date, locale: 'de'), '31.7.2026');
    });

    test('en_GB and de differ from en_US', () {
      final us = formatShortDate(date, locale: 'en_US');
      expect(formatShortDate(date, locale: 'en_GB'), isNot(us));
      expect(formatShortDate(date, locale: 'de'), isNot(us));
    });

    test('falls back to the ambient locale when none is passed', () {
      Intl.defaultLocale = 'en_GB';
      expect(formatShortDate(date), '31/07/2026');
      Intl.defaultLocale = 'de';
      expect(formatShortDate(date), '31.7.2026');
    });

    test('unknown locale falls back instead of throwing', () {
      Intl.defaultLocale = 'en_US';
      expect(
        () => formatShortDate(date, locale: 'zz_ZZ_NOPE'),
        returnsNormally,
      );
      expect(formatShortDate(date, locale: 'zz_ZZ_NOPE'), '7/31/2026');
    });
  });

  group('formatTimestamp', () {
    final ms = date.millisecondsSinceEpoch;

    test('absolute form is locale-aware', () {
      expect(formatTimestamp(ms, locale: 'en_US'), '7/31/2026');
      expect(formatTimestamp(ms, locale: 'en_GB'), '31/07/2026');
      expect(formatTimestamp(ms, locale: 'de'), '31.7.2026');
    });

    test('relative form still short-circuits before formatting', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(formatTimestamp(now, relative: true, locale: 'de'), 'Just now');
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 8, 20, 10);

    test('older than a week uses the locale-aware absolute fallback', () {
      expect(
        formatRelativeTime(date, now: now, locale: 'en_US'),
        '7/31/2026',
      );
      expect(
        formatRelativeTime(date, now: now, locale: 'en_GB'),
        '31/07/2026',
      );
      expect(formatRelativeTime(date, now: now, locale: 'de'), '31.7.2026');
    });

    test('explicit absoluteFallback still wins over locale', () {
      expect(
        formatRelativeTime(
          date,
          now: now,
          locale: 'de',
          absoluteFallback: (d) => 'custom-${d.year}',
        ),
        'custom-2026',
      );
    });

    test('relative buckets are unaffected by locale', () {
      final recent = now.subtract(const Duration(hours: 3));
      expect(formatRelativeTime(recent, now: now, locale: 'de'), '3h ago');
      expect(
        formatRelativeTime(recent, now: now, locale: 'de', compact: true),
        '3h',
      );
    });

    test('yesterday label wins over the absolute date', () {
      final yesterday = now.subtract(const Duration(hours: 25));
      expect(
        formatRelativeTime(
          yesterday,
          now: now,
          useYesterdayLabel: true,
          locale: 'de',
        ),
        'Yesterday',
      );
    });
  });
}
