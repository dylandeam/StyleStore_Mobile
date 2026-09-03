import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Base API URL dynamically resolving based on execution target
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    } else if (Platform.isAndroid) {
      // 10.0.2.2 points to host localhost in Android Emulator
      return 'http://10.0.2.2:8000/api/v1';
    } else {
      // Windows / macOS / Linux / iOS simulator
      return 'http://localhost:8000/api/v1';
    }
  }

  // Auth endpoints
  static String get registerUrl => '$baseUrl/auth/register';
  static String get loginUrl => '$baseUrl/auth/login';
  static String get logoutUrl => '$baseUrl/auth/logout';
  static String get refreshUrl => '$baseUrl/auth/refresh';

  // User endpoints
  static String get meUrl => '$baseUrl/users/me';
}
