import 'package:intl/intl.dart';

/// `US$ 9.99`: explicit currency, Latin American decimal style.
String formatPrice(int cents, String currency) {
  final symbol = currency == 'USD' ? r'US$ ' : '$currency ';
  final format = NumberFormat.currency(
    locale: 'es_419',
    name: currency,
    symbol: symbol,
    decimalDigits: 2,
  );
  return format.format(cents / 100);
}

/// `20 de septiembre`, in the device's local calendar.
String formatLongDate(DateTime date) =>
    DateFormat.MMMMd('es').format(date.toLocal());
