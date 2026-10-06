import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
  }

  static DateTime? parseDate(String value) {
    try {
      return DateFormat('dd/MM/yyyy').parse(value);
    } catch (_) {
      return null;
    }
  }
}
