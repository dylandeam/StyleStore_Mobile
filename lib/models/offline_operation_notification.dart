class OfflineOperationNotification {
  final String title;
  final String body;
  final String route;

  const OfflineOperationNotification({
    required this.title,
    required this.body,
    required this.route,
  });
}

OfflineOperationNotification describeOfflineOperationResult({
  required String operationType,
  required String status,
  String? reason,
  String? productCode,
}) {
  final confirmed = status == 'confirmada';
  if (!confirmed) {
    final cleanReason = reason?.trim() ?? '';
    final lowerReason = cleanReason.toLowerCase();
    final stockConflict = lowerReason.contains('stock') ||
        lowerReason.contains('agot') ||
        lowerReason.contains('disponib');
    if (operationType == 'reserva' && stockConflict) {
      return const OfflineOperationNotification(
        title: 'Reserva no realizada · prenda agotada',
        body:
            'Otra compra o reserva agotó la prenda antes de sincronizar. No se descontó ni se cobró nada.',
        route: '/cuenta/operaciones-pendientes',
      );
    }
    if (operationType == 'reserva') {
      return OfflineOperationNotification(
        title: 'Reserva no realizada',
        body: cleanReason.isNotEmpty
            ? 'No pudimos confirmar tu reserva: $cleanReason'
            : 'No pudimos confirmar tu reserva guardada sin conexión. Revisa el detalle.',
        route: '/cuenta/operaciones-pendientes',
      );
    }
    return OfflineOperationNotification(
      title: 'Operación pendiente de revisión',
      body: cleanReason.isNotEmpty
          ? 'No pudimos completar la acción: $cleanReason'
          : 'No pudimos completar la acción guardada sin conexión. Revisa el detalle.',
      route: '/cuenta/operaciones-pendientes',
    );
  }
  switch (operationType) {
    case 'reserva':
      return const OfflineOperationNotification(
        title: 'Reserva confirmada',
        body: 'Tu reserva guardada sin conexión fue confirmada correctamente.',
        route: '/cuenta/mis-compras',
      );
    case 'venta_efectivo':
      return const OfflineOperationNotification(
        title: 'Venta sincronizada',
        body: 'La venta registrada sin conexión fue confirmada correctamente.',
        route: '/admin/ventas',
      );
    case 'resena_producto':
      return OfflineOperationNotification(
        title: 'Opinión publicada',
        body: 'Tu comentario y calificación ya están publicados.',
        route: productCode?.isNotEmpty == true
            ? '/catalogo/producto/$productCode'
            : '/catalogo',
      );
    default:
      return const OfflineOperationNotification(
        title: 'Operación completada',
        body:
            'La acción que realizaste sin conexión fue confirmada correctamente.',
        route: '/cuenta/operaciones-pendientes',
      );
  }
}
