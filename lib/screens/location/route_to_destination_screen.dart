import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../models/user.dart';
import '../../models/location.dart' as loc;
import '../../services/location_service.dart';

class RouteToDestinationScreen extends StatefulWidget {
  final User destinationUser;
  final loc.Location destinationLocation;

  const RouteToDestinationScreen({
    super.key,
    required this.destinationUser,
    required this.destinationLocation,
  });

  @override
  State<RouteToDestinationScreen> createState() => _RouteToDestinationScreenState();
}

class _RouteToDestinationScreenState extends State<RouteToDestinationScreen> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  late Future<Map<String, dynamic>> _routeDataFuture;

  @override
  void initState() {
    super.initState();
    _routeDataFuture = _calculateAndDrawRoute();
  }

  /// Orquesta todo el proceso: obtiene ubicaciones, llama al servicio y dibuja la ruta real.
  Future<Map<String, dynamic>> _calculateAndDrawRoute() async {
    // 1. Permisos y ubicación del administrador
    await _handleLocationPermission();
    final Position adminPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final LatLng startPoint = LatLng(adminPosition.latitude, adminPosition.longitude);
    final LatLng endPoint = LatLng(widget.destinationLocation.latitude, widget.destinationLocation.longitude);

    // 2. Token de autenticación
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('Sesión expirada.');

    // 3. Llamada al backend para obtener la información de la ruta
    final routeInfo = await LocationService.getDistance(
      token,
      startPoint.latitude,
      startPoint.longitude,
      endPoint.latitude,
      endPoint.longitude,
    );

    // 4. Decodificar la polyline y construir los elementos del mapa
    if (routeInfo.containsKey('polyline')) {
      final String encodedPolyline = routeInfo['polyline'];
      _buildMapElements(startPoint, endPoint, encodedPolyline);
    } else {
      // Fallback por si el backend no devolviera la polyline.
      _buildMapElements(startPoint, endPoint, null);
    }

    // 5. Centrar el mapa para que la ruta sea visible
    _centerMapToShowRoute(startPoint, endPoint);

    return routeInfo;
  }

  /// Decodifica la polyline y crea los marcadores y la ruta en el mapa.
  void _buildMapElements(LatLng startPoint, LatLng endPoint, String? encodedPolyline) {
    _markers.clear();
    _polylines.clear();

    List<LatLng> polylineCoordinates = [];

    // Si tenemos la polyline del backend, la decodificamos y usamos para la ruta.
    if (encodedPolyline != null) {
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decodedPolylinePoints = polylinePoints.decodePolyline(encodedPolyline);
      if (decodedPolylinePoints.isNotEmpty) {
        polylineCoordinates = decodedPolylinePoints.map((point) {
          return LatLng(point.latitude, point.longitude);
        }).toList();
      }
    }

    // Si no hay ruta decodificada, dibuja una línea recta como fallback.
    if (polylineCoordinates.isEmpty) {
      polylineCoordinates = [startPoint, endPoint];
    }

    // Marcador de Origen (Administrador)
    _markers.add(Marker(
      markerId: const MarkerId('start_point'),
      position: startPoint,
      infoWindow: const InfoWindow(title: 'Mi Ubicación', snippet: 'Punto de partida'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    // Marcador de Destino (Usuario)
    _markers.add(Marker(
      markerId: const MarkerId('end_point'),
      position: endPoint,
      infoWindow: InfoWindow(title: 'Destino', snippet: widget.destinationUser.name),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // AÑADIMOS LA RUTA REAL (Polyline) AL MAPA
    _polylines.add(Polyline(
      polylineId: const PolylineId('real_route_line'),
      points: polylineCoordinates, // Usamos los puntos decodificados o la línea recta
      color: Colors.blueAccent,
      width: 5,
    ));
  }

  /// Ajusta la cámara del mapa para que ambos puntos sean visibles.
  Future<void> _centerMapToShowRoute(LatLng start, LatLng end) async {
    final GoogleMapController controller = await _mapControllerCompleter.future;
    // Da un pequeño respiro para que el mapa se inicialice antes de animar la cámara
    await Future.delayed(const Duration(milliseconds: 500));
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            start.latitude < end.latitude ? start.latitude : end.latitude,
            start.longitude < end.longitude ? start.longitude : end.longitude,
          ),
          northeast: LatLng(
            start.latitude > end.latitude ? start.latitude : end.latitude,
            start.longitude > end.longitude ? start.longitude : end.longitude,
          ),
        ),
        100.0, // Padding (espacio) alrededor de la ruta
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ruta a ${widget.destinationUser.name}'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _routeDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Calculando ruta...')]));
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Error: ${snapshot.error.toString().replaceAll("Exception: ", "")}', textAlign: TextAlign.center)));
          }
          if (snapshot.hasData) {
            final routeData = snapshot.data!;
            final distance = routeData['distance']['text'];
            final duration = routeData['duration']['text'];

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: LatLng(widget.destinationLocation.latitude, widget.destinationLocation.longitude), zoom: 14),
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapControllerCompleter.isCompleted) {
                      _mapControllerCompleter.complete(controller);
                    }
                  },
                  markers: _markers,
                  polylines: _polylines, // Dibuja la ruta de carretera
                ),
                Positioned(
                  bottom: 20,
                  left: 10,
                  right: 10,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoColumn(Icons.social_distance_outlined, 'Distancia', distance),
                          _buildInfoColumn(Icons.timer_outlined, 'Duración', duration),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            );
          }
          return const Center(child: Text('Iniciando cálculo de ruta.'));
        },
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Future<void> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están deshabilitados.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación fueron denegados.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Los permisos están permanentemente denegados.');
    }
  }
}