import 'package:intl/intl.dart';

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

  /// Format as "Today at HH:mm", "Yesterday at HH:mm", or "MMM d, yyyy HH:mm"
  String toRelativeTimeString() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisDate = DateTime(year, month, day);

    final time = DateFormat('HH:mm').format(this);

    if (thisDate == today) {
      return 'Today at $time';
    } else if (thisDate == yesterday) {
      return 'Yesterday at $time';
    } else {
      return DateFormat('MMM d, yyyy HH:mm').format(this);
    }
  }
}
