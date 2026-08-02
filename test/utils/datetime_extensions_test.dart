import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:happy_flutter/core/utils/datetime_extensions.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('toIsoTimeString', () {
    test('formats time with milliseconds', () {
      final dt = DateTime(2024, 1, 15, 9, 30, 45, 123);
      expect(dt.toIsoTimeString(), '09:30:45.123');
    });

    test('pads single digits', () {
      final dt = DateTime(2024, 1, 1, 1, 2, 3, 4);
      expect(dt.toIsoTimeString(), '01:02:03.004');
    });

    test('midnight', () {
      final dt = DateTime(2024, 1, 1, 0, 0, 0, 0);
      expect(dt.toIsoTimeString(), '00:00:00.000');
    });

    test('end of day', () {
      final dt = DateTime(2024, 1, 1, 23, 59, 59, 999);
      expect(dt.toIsoTimeString(), '23:59:59.999');
    });
  });

  group('toTimeString', () {
    test('formats as HH:mm:ss', () {
      final dt = DateTime(2024, 1, 15, 9, 30, 45);
      final result = dt.toTimeString();
      // Format depends on locale, but should contain time components
      expect(result, contains('09'));
      expect(result, contains('30'));
      expect(result, contains('45'));
    });
  });

  group('toIsoDateString', () {
    test('formats as yyyy-MM-dd', () {
      final dt = DateTime(2024, 3, 15);
      expect(dt.toIsoDateString(), '2024-03-15');
    });

    test('pads single-digit month and day', () {
      final dt = DateTime(2024, 1, 5);
      expect(dt.toIsoDateString(), '2024-01-05');
    });

    test('handles end of year', () {
      final dt = DateTime(2024, 12, 31);
      expect(dt.toIsoDateString(), '2024-12-31');
    });
  });

  group('toRelativeTimeString', () {
    test('returns Today for today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 30);
      final result = today.toRelativeTimeString();
      expect(result, startsWith('Today at '));
      expect(result, contains('14:30'));
    });

    test('returns Yesterday for yesterday', () {
      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final dt = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        9,
        15,
      );
      final result = dt.toRelativeTimeString();
      expect(result, startsWith('Yesterday at '));
      expect(result, contains('09:15'));
    });

    test('returns formatted date for older dates', () {
      final dt = DateTime(2020, 6, 15, 10, 30);
      final result = dt.toRelativeTimeString();
      expect(result, contains('2020'));
      expect(result, contains('Jun'));
      expect(result, contains('10:30'));
    });

    test('older dates honour the requested locale', () {
      final dt = DateTime(2020, 6, 15, 10, 30);
      final en = dt.toRelativeTimeString(locale: 'en');
      final de = dt.toRelativeTimeString(locale: 'de');
      // The date portion used to be hardcoded to the default locale.
      expect(de, isNot(en));
      expect(de, contains('2020'));
      expect(de, contains('15'));
      expect(de, contains('10:30'));
    });

    test('handles midnight', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 0, 0);
      final result = today.toRelativeTimeString();
      expect(result, 'Today at 00:00');
    });
  });
}
