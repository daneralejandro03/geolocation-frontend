import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {

  static String get backendUrl {
    final url = dotenv.env['BACKEND_GEOLOCATION'];
    if (url == null) {
      throw Exception("La variable de entorno BACKEND_GEOLOCATION no está definida en .env");
    }
    return url;
  }

  static String get mapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null) {
      throw Exception("La variable de entorno GOOGLE_MAPS_API_KEY no está definida en .env");
    }
    return key;
  }
}
