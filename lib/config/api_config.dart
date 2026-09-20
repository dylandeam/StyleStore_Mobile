class ApiConfig {
  /// Base API URL pointing directly to the deployed Railway Production Backend
  static const String baseUrl =
      'https://stylestorebackend-production.up.railway.app/api/v1';

  // Auth endpoints
  static const String registerUrl = '$baseUrl/auth/register';
  static const String loginUrl = '$baseUrl/auth/login';
  static const String logoutUrl = '$baseUrl/auth/logout';
  static const String refreshUrl = '$baseUrl/auth/refresh';

  // Password endpoints (CU4)
  static const String requestPasswordChangeUrl = '$baseUrl/password/request-change';
  static const String confirmPasswordChangeUrl = '$baseUrl/password/confirm';

  // User & Profile endpoints (CU6)
  static const String meUrl = '$baseUrl/users/me';

  // Catálogo y Próximamente (CU11, CU14)
  static const String catalogoUrl = '$baseUrl/catalogo';
  static const String proximamenteUrl = '$baseUrl/proximamente';
  static const String suscribirProximamenteUrl = '$baseUrl/notificaciones/suscribir-proximamente';
  static const String notificacionesUrl = '$baseUrl/notificaciones';

  // Carrito de compras (CU12)
  static const String carritoUrl = '$baseUrl/carrito';
  static const String carritoAgregarUrl = '$baseUrl/carrito/agregar';
  static const String carritoCheckoutUrl = '$baseUrl/carrito/checkout';

  // Reservas (CU13)
  static const String reservasUrl = '$baseUrl/reservas';
  static const String reservasElegibilidadUrl = '$baseUrl/reservas/elegibilidad';

  // Cambios y Devoluciones (v6 Punto 9)
  static const String cambiosUrl = '$baseUrl/cambios';

  // Sucursales
  static const String sucursalesUrl = '$baseUrl/sucursales';

  // Ventas y Pedidos
  static const String misComprasUrl = '$baseUrl/ventas/mis-compras';

  // Envíos (CU19)
  static const String cotizarEnvioUrl = '$baseUrl/envios/cotizar';
  static const String enviosUrl = '$baseUrl/envios';

  // Delivery StyleStore - Rastreo GPS (v7)
  static String rastreoPublicoUrl(String token) => '$baseUrl/envios/rastreo/$token';
  static String conductorGpsUrl(int envioId) => '$baseUrl/envios/$envioId/gps';
}
