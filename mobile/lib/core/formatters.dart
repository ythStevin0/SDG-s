String formatIntId(num value) {
  final intVal = value.round();
  final neg = intVal < 0;
  var s = intVal.abs().toString();
  final parts = <String>[];
  while (s.length > 3) {
    parts.insert(0, s.substring(s.length - 3));
    s = s.substring(0, s.length - 3);
  }
  parts.insert(0, s);
  return '${neg ? "-" : ""}${parts.join(".")}';
}

String formatRupiah(num value, {bool showPlus = false}) {
  final intVal = value.round();
  if (intVal < 0) {
    return '-Rp${formatIntId(intVal.abs())}';
  }
  final prefix = showPlus && intVal > 0 ? '+' : '';
  return '${prefix}Rp${formatIntId(intVal)}';
}

String formatRupiahCompact(num value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 1000000) {
    final jt = (abs / 1000000).toStringAsFixed(2).replaceAll('.', ',');
    return '${sign}Rp$jt jt';
  }
  if (abs >= 1000) {
    final rb = (abs / 1000).toStringAsFixed(0);
    return '${sign}Rp$rb rb';
  }
  return formatRupiah(value);
}

String formatKg(num value) {
  if (value == value.roundToDouble()) {
    return '${formatIntId(value)} kg';
  }
  return '${value.toStringAsFixed(1).replaceAll('.', ',')} kg';
}

String formatStatusLabel(String status) {
  return status.replaceAll('_', ' ').toUpperCase();
}
