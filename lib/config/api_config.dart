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

  // Carrito de compras (CU12)
  static const String carritoUrl = '$baseUrl/carrito';
  static const String carritoAgregarUrl = '$baseUrl/carrito/agregar';
  static const String carritoCheckoutUrl = '$baseUrl/carrito/checkout';

  // Reservas (CU13)
  static const String reservasUrl = '$baseUrl/reservas';

  // Ventas y Pedidos
  static const String misComprasUrl = '$baseUrl/ventas/mis-compras';

  // Envíos (CU19)
  static const String cotizarEnvioUrl = '$baseUrl/envios/cotizar';
  static const String enviosUrl = '$baseUrl/envios';
}
