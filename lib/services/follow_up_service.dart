import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/user.dart';

class FollowUpService {

  static Future<void> followUser(String token, int userIdToFollow) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/followups/$userIdToFollow');
    await ApiClient.handleRequest(http.post(uri, headers: ApiClient.getHeaders(token)));
  }

  static Future<void> unfollowUser(String token, int userIdToUnfollow) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/followups/$userIdToUnfollow');
    await ApiClient.handleRequest(http.delete(uri, headers: ApiClient.getHeaders(token)));
  }

  static Future<List<User>> getFollowing(String token) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/followups/following');
    final response = await ApiClient.handleRequest(http.get(uri, headers: ApiClient.getHeaders(token)));
    final List<dynamic> body = jsonDecode(response.body);
    return body.map((dynamic item) => User.fromJson(item)).toList();
  }

  static Future<List<User>> getMyFollowers(String token) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/followups/followers');
    final response = await ApiClient.handleRequest(http.get(uri, headers: ApiClient.getHeaders(token)));
    final List<dynamic> body = jsonDecode(response.body);
    return body.map((dynamic item) => User.fromJson(item)).toList();
  }
}