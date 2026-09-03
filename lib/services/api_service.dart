import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiService {
  final StorageService _storageService;

  ApiService(this._storageService);

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> get(String url, {bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.get(Uri.parse(url), headers: headers);
  }

  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
