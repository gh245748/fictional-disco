import 'package:intl/intl.dart';

/// Turkish-aware uppercase (i -> İ, ı -> I).
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Turkish-aware lowercase (İ -> i, I -> ı).
String trLower(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

const String _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

/// Compares two strings using the Turkish alphabet, case-insensitively.
/// Characters outside the alphabet fall back to code-unit order.
int trCompare(String a, String b) {
  final x = trLower(a).runes.toList();
  final y = trLower(b).runes.toList();
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    if (x[i] == y[i]) continue;
    final ix = _alphabet.indexOf(String.fromCharCode(x[i]));
    final iy = _alphabet.indexOf(String.fromCharCode(y[i]));
    if (ix >= 0 && iy >= 0) return ix.compareTo(iy);
    // Outside the alphabet: code-unit order.
    return x[i].compareTo(y[i]);
  }
  return x.length.compareTo(y.length);
}

/// "0 dk", "45 dk", "1 sa 15 dk", "2 sa". Seconds below a minute are dropped.
String formatDuration(int seconds) {
  final totalMinutes = seconds ~/ 60;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m dk';
  if (m == 0) return '$h sa';
  return '$h sa $m dk';
}

/// Below 100 h: one decimal with comma, trailing ",0" dropped.
/// From 100 h: integer, grouped with ".".
String formatHours(int seconds) {
  final hours = seconds / 3600;
  if (hours < 100) {
    final tenths = (hours * 10).round();
    if (tenths >= 1000) return '${_group(tenths ~/ 10)} sa';
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '$whole sa' : '$whole,$frac sa';
  }
  return '${_group(hours.round())} sa';
}

String _group(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 0.271 -> "%27".
String formatPercent(double ratio) => '%${(ratio * 100).round()}';

/// "21 Kasım". Requires `initializeDateFormatting('tr')`.
String formatDayMonth(DateTime local) =>
    DateFormat('d MMMM', 'tr').format(local);

/// "Cumartesi". Requires `initializeDateFormatting('tr')`.
String formatWeekday(DateTime local) => DateFormat('EEEE', 'tr').format(local);
