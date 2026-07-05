import '../../extensions/double_extension.dart';

class DashboardFormatters {
  const DashboardFormatters._();

  static String money(double value) {
    return value.toTrimmedPriceString();
  }

  static String recordCountBadge(int count) {
    return count > 99 ? '99+' : '$count';
  }

  static String time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String dateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day ${time(value)}';
  }

  static String monthDay(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month月$day日';
  }
}
