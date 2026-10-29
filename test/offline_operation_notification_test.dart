import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/models/offline_operation_notification.dart';

void main() {
  test('describe claramente cada operación confirmada', () {
    expect(
      describeOfflineOperationResult(
        operationType: 'reserva',
        status: 'confirmada',
      ).title,
      'Reserva confirmada',
    );
    final review = describeOfflineOperationResult(
      operationType: 'resena_producto',
      status: 'confirmada',
      productCode: 'PROD-0001',
    );
    expect(review.title, 'Opinión publicada');
    expect(review.route, '/catalogo/producto/PROD-0001');
  });

  test('explica cuando una reserva offline pierde el último stock', () {
    final result = describeOfflineOperationResult(
      operationType: 'reserva',
      status: 'conflicto',
      reason: 'Stock insuficiente. Disponible: 0, solicitado: 1.',
    );

    expect(result.title, 'Reserva no realizada · prenda agotada');
    expect(result.body, contains('Otra compra o reserva agotó la prenda'));
    expect(result.body, contains('No se descontó ni se cobró nada'));
  });

  test('un conflicto de horario conserva el motivo de la reserva', () {
    final message = describeOfflineOperationResult(
      operationType: 'reserva',
      status: 'conflicto',
      reason: 'El bloque horario ya fue ocupado',
    );
    expect(message.title, 'Reserva no realizada');
    expect(message.body, contains('El bloque horario ya fue ocupado'));
  });
}
