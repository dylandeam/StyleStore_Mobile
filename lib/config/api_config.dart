class ApiConfig {
  /// Base API URL - default set to local network IP for physical device testing
  static String baseUrl = 'http://192.168.0.17:8000/api/v1';

  /// Candidate URLs to attempt connection if default fails
  static List<String> get candidateUrls => [
        'http://192.168.0.17:8000/api/v1',
        'http://10.0.2.2:8000/api/v1',
        'http://localhost:8000/api/v1',
        'https://stylestorebackend-production.up.railway.app/api/v1',
      ];

  /// Resolves relative image paths to full HTTP URLs using active baseUrl
  static String? resolveImageUrl(String? foto) {
    if (foto == null || foto.trim().isEmpty) return null;
    final trimmed = foto.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    try {
      final uri = Uri.parse(baseUrl);
      final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      return '$origin${trimmed.startsWith('/') ? trimmed : '/$trimmed'}';
    } catch (_) {
      return 'http://192.168.0.17:8000${trimmed.startsWith('/') ? trimmed : '/$trimmed'}';
    }
  }

  // Auth endpoints
  static String get registerUrl => '$baseUrl/auth/register';
  static String get loginUrl => '$baseUrl/auth/login';
  static String get logoutUrl => '$baseUrl/auth/logout';
  static String get refreshUrl => '$baseUrl/auth/refresh';

  // Password endpoints (CU4)
  static String get requestPasswordChangeUrl => '$baseUrl/password/request-change';
  static String get confirmPasswordChangeUrl => '$baseUrl/password/confirm';

  // User & Profile endpoints (CU6)
  static String get meUrl => '$baseUrl/users/me';

  // Catálogo y Próximamente (CU11, CU14)
  static String get catalogoUrl => '$baseUrl/catalogo';
  static String get catalogoParaTiUrl => '$baseUrl/catalogo/para-ti';
  static String get proximamenteUrl => '$baseUrl/proximamente';
  static String get suscribirProximamenteUrl => '$baseUrl/notificaciones/suscribir-proximamente';
  static String get notificacionesUrl => '$baseUrl/notificaciones';

  // Carrito de compras (CU12)
  static String get carritoUrl => '$baseUrl/carrito/mio';
  static String get carritoAgregarUrl => '$baseUrl/carrito/items';
  static String get carritoCheckoutUrl => '$baseUrl/carrito/checkout';

  // Reservas (CU13)
  static String get reservasUrl => '$baseUrl/reservas';
  static String get reservasElegibilidadUrl => '$baseUrl/reservas/elegibilidad';

  // Cambios y Devoluciones (v6 Punto 9)
  static String get cambiosUrl => '$baseUrl/cambios';

  // Sucursales
  static String get sucursalesUrl => '$baseUrl/sucursales';

  // Ventas y Pedidos
  static String get misComprasUrl => '$baseUrl/ventas/mis-compras';

  // Envíos (CU19)
  static String get cotizarEnvioUrl => '$baseUrl/envios/cotizar';
  static String get enviosUrl => '$baseUrl/envios';

  // Delivery StyleStore - Rastreo GPS (v7)
  static String rastreoPublicoUrl(String token) => '$baseUrl/envios/rastreo/$token';
  static String conductorGpsUrl(int envioId) => '$baseUrl/envios/$envioId/gps';
  static String webTrackerUrl(String token) => 'https://style-store-frontend-nine.vercel.app/delivery/rastreo/$token';

  // Outfits Combinaciones (Punto 9 / v7)
  static String get outfitsUrl => '$baseUrl/outfits';
  static String outfitDetalleUrl(int id) => '$baseUrl/outfits/$id';
  static String outfitComprarUrl(int id) => '$baseUrl/outfits/$id/comprar';

  // Chatbot Asistente IA (Punto 8 / v7)
  static String get chatbotConversarUrl => '$baseUrl/chatbot/conversar';

  // QR Config Mostrador (Punto Pagos QR)
  static String get qrConfigUrl => '$baseUrl/pagos/config-qr';
}
