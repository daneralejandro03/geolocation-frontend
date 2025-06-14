import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/user.dart';
import '../../models/location.dart' as loc;

class HistoryMapViewScreen extends StatefulWidget {
  final User user;
  final List<loc.Location> locations;

  const HistoryMapViewScreen({
    super.key,
    required this.user,
    required this.locations,
  });

  @override
  State<HistoryMapViewScreen> createState() => _HistoryMapViewScreenState();
}

class _HistoryMapViewScreenState extends State<HistoryMapViewScreen> {
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    if (widget.locations.isNotEmpty) {
      _buildMapElements(widget.locations);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Sin fecha';
    final localDt = dt.toLocal();
    final day = localDt.day.toString().padLeft(2, '0');
    final month = localDt.month.toString().padLeft(2, '0');
    final year = localDt.year.toString();
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _buildMapElements(List<loc.Location> history) {
    final List<LatLng> polylineCoordinates = [];

    for (int i = 0; i < history.length; i++) {
      final location = history[i];
      final position = LatLng(location.latitude, location.longitude);
      polylineCoordinates.add(position);

      final isMostRecent = i == 0;
      final isOldest = i == history.length - 1;

      _markers.add(
        Marker(
          markerId: MarkerId('location_${location.id}'),
          position: position,
          infoWindow: InfoWindow(
            title: isMostRecent ? 'Última Ubicación' : (isOldest ? 'Primera Ubicación' : 'Ubicación #${history.length - i}'),
            snippet: _formatDateTime(location.timestamp),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMostRecent ? BitmapDescriptor.hueRed :
            isOldest ? BitmapDescriptor.hueGreen :
            BitmapDescriptor.hueAzure,
          ),
          zIndex: isMostRecent ? 1.0 : 0.0,
        ),
      );
    }

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('history_path'),
        points: polylineCoordinates,
        color: Colors.blueAccent.withOpacity(0.8),
        width: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = widget.locations.isNotEmpty
        ? LatLng(widget.locations.first.latitude, widget.locations.first.longitude)
        : const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ruta de ${widget.user.name}'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialTarget,
          zoom: 15,
        ),
        markers: _markers,
        polylines: _polylines,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}