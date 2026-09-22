import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
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

  Future<http.Response> _executeWithFallback(
    Future<http.Response> Function(String url) requestFn,
    String endpointUrl,
  ) async {
    try {
      return await requestFn(endpointUrl).timeout(const Duration(seconds: 8));
    } catch (e) {
      // Extract path to try candidate base URLs
      final path = _extractPath(endpointUrl);
      if (path.isNotEmpty) {
        for (final candidateBase in ApiConfig.candidateUrls) {
          if (candidateBase == ApiConfig.baseUrl) continue;
          try {
            final testUrl = candidateBase + path;
            final response = await requestFn(testUrl).timeout(const Duration(seconds: 4));
            // Found working host! Switch baseUrl globally
            ApiConfig.baseUrl = candidateBase;
            return response;
          } catch (_) {
            continue;
          }
        }
      }
      rethrow;
    }
  }

  String _extractPath(String fullUrl) {
    for (final base in ApiConfig.candidateUrls) {
      if (fullUrl.startsWith(base)) {
        return fullUrl.substring(base.length);
      }
    }
    final index = fullUrl.indexOf('/api/v1');
    if (index != -1) {
      return fullUrl.substring(index + 7);
    }
    return '';
  }

  Future<http.Response> get(String url, {bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _executeWithFallback(
      (targetUrl) => http.get(Uri.parse(targetUrl), headers: headers),
      url,
    );
  }

  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return await _executeWithFallback(
      (targetUrl) => http.post(
        Uri.parse(targetUrl),
        headers: headers,
        body: encodedBody,
      ),
      url,
    );
  }

  Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return await _executeWithFallback(
      (targetUrl) => http.put(
        Uri.parse(targetUrl),
        headers: headers,
        body: encodedBody,
      ),
      url,
    );
  }

  Future<http.Response> patch(
    String url, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return await _executeWithFallback(
      (targetUrl) => http.patch(
        Uri.parse(targetUrl),
        headers: headers,
        body: encodedBody,
      ),
      url,
    );
  }

  Future<http.Response> delete(String url, {bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _executeWithFallback(
      (targetUrl) => http.delete(Uri.parse(targetUrl), headers: headers),
      url,
    );
  }
}
