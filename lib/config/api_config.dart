class ApiConfig {
  /// Base API URL pointing directly to the deployed Railway Production Backend
  static const String productionUrl =
      'https://stylestorebackend-production.up.railway.app/api/v1';

  /// Toggle for local development vs production Railway backend
  static const bool useProduction = true;

  static String get baseUrl {
    if (useProduction) {
      return productionUrl;
    }
    // Local fallback
    return 'http://10.0.2.2:8000/api/v1';
  }

  // Auth endpoints
  static String get registerUrl => '$baseUrl/auth/register';
  static String get loginUrl => '$baseUrl/auth/login';
  static String get logoutUrl => '$baseUrl/auth/logout';
  static String get refreshUrl => '$baseUrl/auth/refresh';

  // User endpoints
  static String get meUrl => '$baseUrl/users/me';
}
