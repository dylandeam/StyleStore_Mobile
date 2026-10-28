List<Map<String, dynamic>> buildProvisionalReservationSlots(
  String opening,
  String closing,
) {
  int parseMinutes(String value, int fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return hour * 60 + minute;
  }

  String formatMinutes(int value) {
    final hour = (value ~/ 60).toString().padLeft(2, '0');
    final minute = (value % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  final start = parseMinutes(opening, 9 * 60);
  final end = parseMinutes(closing, 18 * 60);
  if (end <= start) return const [];

  return [
    for (var current = start; current + 60 <= end; current += 60)
      {
        'inicio': formatMinutes(current),
        'fin': formatMinutes(current + 60),
        'disponible': true,
        'provisional': true,
      },
  ];
}
