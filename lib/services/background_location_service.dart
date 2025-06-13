import 'package:background_fetch/background_fetch.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';
import 'socket_service.dart';
import 'location_service.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  if (isTimeout) {
    print("[BackgroundFetch] Headless task TIMEOUT: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }

  print("[BackgroundFetch] Headless event received: $taskId");
  await _sendLocation();
  BackgroundFetch.finish(taskId);
}

Future<void> _sendLocation() async {
  String? token;
  try {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwt_token');
    if (token == null) {
      print("[BackgroundFetch] No hay token, no se puede enviar ubicación.");
      return;
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    print("[BackgroundFetch] Ubicación obtenida: ${position.latitude}, ${position.longitude}");

    final locationToSave = Location(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await LocationService.createLocation(token, locationToSave);
    print("[BackgroundFetch] Ubicación guardada en el historial vía API REST.");


    final socketService = SocketService();
    socketService.connect(token);
    await Future.delayed(const Duration(seconds: 2));
    socketService.emitLocation(position.latitude, position.longitude);

    await Future.delayed(const Duration(seconds: 3));
    socketService.disconnect();

  } catch (e) {
    print("[BackgroundFetch] Error durante el envío de ubicación: $e");
    if (e.toString().contains('401') || e.toString().contains('inválido')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
    }
  }
}

class BackgroundLocationService {
  static Future<void> init() async {
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        startOnBoot: true,
        requiredNetworkType: NetworkType.ANY,
      ),
          (String taskId) async {
        print("[BackgroundFetch] Event received (app active): $taskId");
        await _sendLocation();
        BackgroundFetch.finish(taskId);
      },
          (String taskId) async {
        print("[BackgroundFetch] TASK TIMEOUT: $taskId");
        BackgroundFetch.finish(taskId);
      },
    );
    print("[BackgroundFetch] Servicio de seguimiento en segundo plano configurado.");
  }
}