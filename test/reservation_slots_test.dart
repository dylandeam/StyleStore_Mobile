import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/utils/reservation_slots.dart';

void main() {
  test('genera bloques provisionales completos dentro del horario local', () {
    final slots = buildProvisionalReservationSlots('09:00', '12:30');

    expect(slots, hasLength(3));
    expect(slots.first['inicio'], '09:00');
    expect(slots.last['fin'], '12:00');
    expect(slots.every((slot) => slot['disponible'] == true), isTrue);
    expect(slots.every((slot) => slot['provisional'] == true), isTrue);
  });

  test('usa un horario seguro cuando el dato local es inválido', () {
    final slots = buildProvisionalReservationSlots('sin-hora', 'sin-hora');

    expect(slots, hasLength(9));
    expect(slots.first['inicio'], '09:00');
    expect(slots.last['fin'], '18:00');
  });

  test('serializa la fecha con el contrato date del backend', () {
    expect(formatReservationDate(DateTime(2026, 10, 30, 18, 45)), '2026-10-30');
  });
}
