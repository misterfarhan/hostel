import 'package:intl/intl.dart';

import '../../data/models/models.dart';

abstract final class Fmt {
  static final _compact = NumberFormat.compact();
  static final _grouped = NumberFormat.decimalPattern();

  /// "Rs. 12,000" / "AED 3,500" / "£950". Large one-time prices use compact
  /// notation ("Rs. 1.2 Cr" style is country specific; we use 12M style).
  static String money(double amount, Country country, {bool compact = false}) {
    final value = compact && amount >= 1000000 ? _compact.format(amount) : _grouped.format(amount.round());
    final symbol = country.currencySymbol;
    return symbol.length == 1 ? '$symbol$value' : '$symbol $value';
  }

  static String price(Property p, Country country, {bool compact = false}) {
    final base = money(p.price, country, compact: compact);
    final suffix = p.pricePeriod.suffix;
    return suffix.isEmpty ? base : '$base $suffix';
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dateTime(DateTime d) => DateFormat('EEE d MMM, h:mm a').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  static String relative(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(d);
  }

  static String count(num n) => n >= 10000 ? _compact.format(n) : _grouped.format(n);
}
