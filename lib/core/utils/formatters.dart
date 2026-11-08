import 'package:intl/intl.dart';

/// Utility formatting helpers used throughout the app.
abstract class Formatters {
  static final _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _shortDateFmt = DateFormat('dd/MM/yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  /// Formats [amount] as Indian Rupee currency string.
  /// e.g. 1500 -> ₹1,500
  static String currency(num? amount) {
    if (amount == null) return '₹0';
    return _currencyFmt.format(amount);
  }

  /// Formats a [DateTime] as 'dd MMM yyyy'.
  static String date(DateTime? dt) {
    if (dt == null) return '-';
    return _dateFmt.format(dt);
  }

  /// Formats a [DateTime] as 'dd/MM/yyyy'.
  static String shortDate(DateTime? dt) {
    if (dt == null) return '-';
    return _shortDateFmt.format(dt);
  }

  /// Formats a [DateTime] as 'dd MMM yyyy, hh:mm a'.
  static String dateTime(DateTime? dt) {
    if (dt == null) return '-';
    return _dateTimeFmt.format(dt);
  }

  /// Returns a relative time label: 'Today', 'Yesterday', or formatted date.
  static String relative(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return date(dt);
  }

  /// Compact currency: ₹1.2K, ₹1.5L, or full for small amounts.
  static String compactCurrency(num? amount) {
    if (amount == null) return '₹0';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return _currencyFmt.format(amount);
  }

  /// Formats [dt] as 'Mon, 17 Sep 2026 • 4:32 PM' — used for the "Added on" display.
  static String createdAtFull(DateTime dt) {
    final dayName = DateFormat('EEE').format(dt);   // Mon, Tue …
    final datePart = DateFormat('dd MMM yyyy').format(dt);
    final timePart = DateFormat('hh:mm a').format(dt);
    return '$dayName, $datePart • $timePart';
  }
}
