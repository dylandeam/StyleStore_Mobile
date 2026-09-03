class ApiConfig {
  /// Base API URL pointing directly to the deployed Railway Production Backend
  static const String baseUrl =
      'https://stylestorebackend-production.up.railway.app/api/v1';

  // Auth endpoints
  static const String registerUrl = '$baseUrl/auth/register';
  static const String loginUrl = '$baseUrl/auth/login';
  static const String logoutUrl = '$baseUrl/auth/logout';
  static const String refreshUrl = '$baseUrl/auth/refresh';

  // User endpoints
  static const String meUrl = '$baseUrl/users/me';
}
