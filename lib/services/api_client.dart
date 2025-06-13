import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/env.dart';

class ApiClient {
  static final String baseUrl = Env.backendUrl;

  static Map<String, String> getHeaders(String? token) {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> handleRequest(Future<http.Response> request) async {
    try {
      final response = await request.timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body);
        final message = body['message'] ?? 'Error desconocido del servidor.';
        throw Exception('$message (Código: ${response.statusCode})');
      }
      return response;
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado. El servidor no respondió.');
    } catch (e) {
      if (e is Exception) {
        throw e;
      }
      throw Exception('No se pudo conectar al servidor. Revisa la conexión.');
    }
  }
}