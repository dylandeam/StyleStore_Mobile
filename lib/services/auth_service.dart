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

    _status = AuthStatus.authenticated;
    notifyListeners();

    // Try fetching user profile without logging out on failure
    await fetchProfile();
  }

  Future<bool> register({
    required String name,
    String? apellido,
    required String email,
    required String password,
    required List<String> empresaCodigos,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> body = {
        'name': name,
        'email': email,
        'password': password,
      };
      if (apellido != null && apellido.trim().isNotEmpty) {
        body['apellido'] = apellido.trim();
      }
      body['empresa_codigos'] = empresaCodigos
          .map((code) => code.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList();

      final response = await _apiService.post(
        ApiConfig.registerUrl,
        body: body,
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

  Future<List<Map<String, dynamic>>> getRegistrationCompanies() async {
    final response = await _apiService.get(
      '${ApiConfig.baseUrl}/empresas/publicas/registro',
      requireAuth: false,
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las empresas disponibles.');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTenants() async {
    final response = await _apiService.get('${ApiConfig.baseUrl}/auth/tenants');
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar tus empresas.');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> selectTenant(int empresaId) async {
    final response = await _apiService.post(
      '${ApiConfig.baseUrl}/auth/tenants/select',
      body: {'empresa_id': empresaId},
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'No se pudo cambiar de empresa.');
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    await _storageService.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    await fetchProfile();
  }

  Future<Map<String, dynamic>?> getTenantDetails() async {
    try {
      final response = await _apiService.get(ApiConfig.miEmpresaUrl);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getTenantSubscription() async {
    try {
      final response = await _apiService.get(ApiConfig.miContratacionUrl);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
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
    final hasToken = await _storageService.hasToken();
    if (!hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final response = await _apiService.get(ApiConfig.meUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data);
        _status = AuthStatus.authenticated;
      } else {
        // Keep session active even if profile fetch has a temporary issue
        _status = AuthStatus.authenticated;
      }
    } catch (_) {
      // Keep session active on network lag/offline
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  void updateCurrentUser(User user) {
    _currentUser = user;
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
