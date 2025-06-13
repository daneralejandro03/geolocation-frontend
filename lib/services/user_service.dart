import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/user.dart';

class UserService {
  static Future<User> getProfile(String token) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/users/profile');
    final response = await ApiClient.handleRequest(http.get(uri, headers: ApiClient.getHeaders(token)));
    return User.fromJson(jsonDecode(response.body));
  }

  static Future<List<User>> getAllUsers(String token) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/users');
    final response = await ApiClient.handleRequest(http.get(uri, headers: ApiClient.getHeaders(token)));
    final List<dynamic> body = jsonDecode(response.body);
    return body.map((dynamic item) => User.fromJson(item)).toList();
  }

  static Future<User> getUserById(String token, int userId) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/users/$userId');
    final response = await ApiClient.handleRequest(http.get(uri, headers: ApiClient.getHeaders(token)));
    return User.fromJson(jsonDecode(response.body));
  }

  static Future<User> createUser({
    required String token,
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/users');
    final response = await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(token),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'rol': role,
      }),
    ));
    return User.fromJson(jsonDecode(response.body));
  }
}