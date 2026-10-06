import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static String currency(double amount) {
    return NumberFormat.currency(
      symbol: 'PKR ',
      decimalDigits: 2,
    ).format(amount);
  }

  static String number(double value) {
    return NumberFormat('#,##0.##').format(value);
  }

  static String integer(int value) {
    return NumberFormat('#,##0').format(value);
  }
}
