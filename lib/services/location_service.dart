import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/location.dart';

class LocationService {
  static Future<Location> createLocation(String token, Location location) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/locations');
    final response = await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(token),
      body: jsonEncode(location.toJson()),
    ));
    return Location.fromJson(jsonDecode(response.body));
  }

  static Future<List<Location>> getLocationHistory(String token, int userId) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/locations/$userId');
    final response = await ApiClient.handleRequest(http.get(uri, headers: ApiClient.getHeaders(token)));
    final List<dynamic> body = jsonDecode(response.body);
    return body.map((dynamic item) => Location.fromJson(item)).toList();
  }

  static Future<Map<String, dynamic>> getDistance(String token, double lat1, double lon1, double lat2, double lon2) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/locations/distance');
    final response = await ApiClient.handleRequest(http.post(
      uri,
      headers: ApiClient.getHeaders(token),
      body: jsonEncode({
        'lat1': lat1, 'lon1': lon1, 'lat2': lat2, 'lon2': lon2
      }),
    ));
    return jsonDecode(response.body);
  }
}