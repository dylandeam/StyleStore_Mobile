import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  User? _currentUser;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;

  AuthService(this._apiService, this._storageService) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final hasToken = await _storageService.hasToken();
    if (!hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Try fetching user profile
    await fetchProfile();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConfig.registerUrl,
        body: {
          'name': name,
          'email': email,
          'password': password,
        },
        requireAuth: false,
      );

      if (response.statusCode == 201) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['detail'] ?? 'Error durante el registro';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión con el servidor ($e)';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConfig.loginUrl,
        body: {
          'email': email,
          'password': password,
        },
        requireAuth: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        await _storageService.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        // Fetch user profile immediately
        await fetchProfile();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['detail'] ?? 'Credenciales incorrectas';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al conectar con el servidor ($e)';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final response = await _apiService.get(ApiConfig.meUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data);
        _status = AuthStatus.authenticated;
      } else {
        await logout();
      }
    } catch (_) {
      await logout();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _apiService.post(ApiConfig.logoutUrl);
    } catch (_) {
      // Ignore network error on logout
    }

    await _storageService.clearTokens();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
