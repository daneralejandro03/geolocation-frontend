import 'package:socket_io_client/socket_io_client.dart' as io;
import '../utils/env.dart';
import '../models/location.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() {
    return _instance;
  }
  SocketService._internal();
  io.Socket? _socket;

  void connect(String token) {
    if (_socket != null && _socket!.connected) {
      print('SocketService: Ya existe una conexión activa.');
      return;
    }

    final url = Env.backendUrl.replaceFirst('http', 'ws');

    _socket = io.io('$url/geolocation', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {
        'Authorization': 'Bearer $token',
      }
    });

    _socket!.onConnect((_) => print('SocketService: Conectado al Gateway de geolocalización.'));
    _socket!.onDisconnect((_) => print('SocketService: Desconectado del Gateway.'));
    _socket!.onConnectError((data) => print('SocketService Error de Conexión: $data'));
    _socket!.onError((data) => print('SocketService Error General: $data'));

    _socket!.connect();
  }

  void emitLocation(double lat, double lng) {
    if (_socket == null || !_socket!.connected) {
      print("Socket no conectado. No se puede emitir la ubicación.");
      return;
    }
    _socket!.emit('sendLocation', {'latitude': lat, 'longitude': lng});
    print('Ubicación emitida vía WebSocket: ($lat, $lng)');
  }

  void onNewLocation(void Function(Location location) callback) {
    _socket?.on('newLocation', (data) {
      print("SocketService: Recibido 'newLocation' con data: $data");
      try {
        final location = Location.fromJson(data);
        callback(location);
      } catch (e) {
        print("Error al parsear la nueva ubicación del WebSocket: $e");
      }
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    print("SocketService: Conexión cerrada y recursos liberados.");
  }
}
