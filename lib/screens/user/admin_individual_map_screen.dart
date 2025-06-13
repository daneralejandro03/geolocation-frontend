import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/location.dart';
import '../../models/user.dart';
import '../../services/socket_service.dart';
import '../auth/login_screen.dart';

class AdminIndividualMapScreen extends StatefulWidget {
  final User userToTrack;

  const AdminIndividualMapScreen({super.key, required this.userToTrack});

  @override
  State<AdminIndividualMapScreen> createState() => _AdminIndividualMapScreenState();
}

class _AdminIndividualMapScreenState extends State<AdminIndividualMapScreen> {
  final SocketService _socketService = SocketService();
  GoogleMapController? _mapController;
  Marker? _userMarker;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      if(mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
      return;
    }

    _socketService.connect(token);
    _listenForLocationUpdates();
  }

  void _listenForLocationUpdates() {
    _socketService.onNewLocation((Location location) {
      if (location.userId == widget.userToTrack.id) {
        final newPosition = LatLng(location.latitude, location.longitude);
        if (mounted) {
          setState(() {
            _userMarker = Marker(
              markerId: MarkerId(location.userId.toString()),
              position: newPosition,
              infoWindow: InfoWindow(
                title: location.userName ?? widget.userToTrack.name,
                snippet: 'Actualizado: ${TimeOfDay.fromDateTime(location.timestamp!.toLocal()).format(context)}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            );
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ubicación de ${widget.userToTrack.name}'),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(4.8133, -75.496), // Posición inicial
          zoom: 12,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _userMarker != null ? {_userMarker!} : {},
      ),
    );
  }
}
