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

  test('un conflicto explica que la operación necesita revisión', () {
    final message = describeOfflineOperationResult(
      operationType: 'reserva',
      status: 'conflicto',
      reason: 'Stock insuficiente',
    );
    expect(message.title, 'Operación pendiente de revisión');
    expect(message.body, contains('Stock insuficiente'));
  });
}
