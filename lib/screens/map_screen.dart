import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';

import '../services/background_location_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../models/location.dart';
import 'auth/login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SocketService _socketService = SocketService();
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _loadingMessage = "Iniciando...";
  StreamSubscription<Position>? _positionStream;
  Timer? _foregroundSendTimer;

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(4.8133, -75.496),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _foregroundSendTimer?.cancel();
    _socketService.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _loadingMessage = "Configurando servicio de fondo...");
    await BackgroundLocationService.init();

    setState(() => _loadingMessage = "Verificando permisos...");
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _logout();
      return;
    }
    _socketService.connect(token);

    setState(() => _loadingMessage = "Obteniendo ubicación...");
    _currentPosition = await Geolocator.getCurrentPosition();

    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      if (mounted) setState(() => _currentPosition = position);
    });

    _startPeriodicSending();

    setState(() => _isLoading = false);
  }

  void _startPeriodicSending() {
    _foregroundSendTimer?.cancel();
    _foregroundSendTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentPosition != null) {
        print("[ForegroundSend] Enviando ubicación por temporizador...");
        _sendCurrentLocation();
      }
    });
  }

  Future<void> _sendCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || _currentPosition == null) return;

    try {
      final locationToSave = Location(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
      await LocationService.createLocation(token, locationToSave);

      _socketService.emitLocation(_currentPosition!.latitude, _currentPosition!.longitude);

    } catch (e) {
      print("Error en envío de ubicación en primer plano: $e");
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los servicios de ubicación están deshabilitados.')));
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los permisos de ubicación fueron denegados.')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los permisos están permanentemente denegados.')));
      return false;
    }
    return true;
  }

  void _centerMapOnLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 17.0,
        ),
      ));
    }
  }

  Future<void> _logout() async {
    await BackgroundFetch.stop();
    _foregroundSendTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _socketService.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_loadingMessage)]))
          : GoogleMap(
        initialCameraPosition: _currentPosition != null
            ? CameraPosition(target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 17.0)
            : _kInitialPosition,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          if (_currentPosition != null) _centerMapOnLocation();
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
      ),
      floatingActionButton: _isLoading ? null : FloatingActionButton(
        onPressed: _centerMapOnLocation,
        tooltip: 'Centrar Mapa',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}