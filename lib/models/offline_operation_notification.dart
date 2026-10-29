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
    return OfflineOperationNotification(
      title: 'Operación pendiente de revisión',
      body: reason?.trim().isNotEmpty == true
          ? 'No pudimos completar la acción: ${reason!.trim()}'
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
