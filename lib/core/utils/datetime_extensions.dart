import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String toIsoTimeString() {
    final formatter = DateFormat.Hms();
    return formatter.format(this);
  }
}
