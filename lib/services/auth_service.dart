import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart'; // Importamos nuestro cliente base
import '../models/user.dart';

class AuthService {
  static Future<String> login(String email, String password) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/auth/login');
    final response = await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(null), // Sin token para login
      body: jsonEncode({'email': email, 'password': password}),
    ));
    return jsonDecode(response.body)['access_token'] as String;
  }

  static Future<User> register(String name, String email, String password) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/auth/register');
    final response = await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(null),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    ));
    return User.fromJson(jsonDecode(response.body));
  }

  static Future<void> requestPasswordRecovery(String email) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/auth/requestPasswordRecovery');
    await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(null),
      body: jsonEncode({'email': email}),
    ));
  }

  static Future<void> resetPassword({
    required String pin,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/auth/resetPassword');
    await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(null),
      body: jsonEncode({
        'token': pin,
        'newPassword': newPassword,
      }),
    ));
  }

}