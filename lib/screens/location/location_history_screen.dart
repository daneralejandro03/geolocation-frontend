import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../models/location.dart' as loc;
import '../../services/location_service.dart';
import 'history_map_view_screen.dart';
import 'route_to_destination_screen.dart';

class LocationHistoryScreen extends StatefulWidget {
  final User user;
  const LocationHistoryScreen({super.key, required this.user});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  late Future<List<loc.Location>> _historyFuture;
  List<loc.Location>? _cachedHistory;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<loc.Location>> _fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('No estás autenticado.');

    final history = await LocationService.getLocationHistory(token, widget.user.id);
    if (history.isEmpty) throw Exception('Este usuario no tiene historial de ubicaciones.');

    _cachedHistory = history;
    return history;
  }

  void _navigateToCompleteRouteView() {
    if (_cachedHistory != null && _cachedHistory!.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => HistoryMapViewScreen(user: widget.user, locations: _cachedHistory!),
      ));
    }
  }

  void _navigateToRouteToLastLocation(loc.Location lastLocation) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RouteToDestinationScreen(
          destinationUser: widget.user,
          destinationLocation: lastLocation
      ),
    ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de ${widget.user.name}'),
      ),
      body: FutureBuilder<List<loc.Location>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(snapshot.error.toString().replaceAll("Exception: ", ""), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16))));
          }
          if (snapshot.hasData) {
            final history = snapshot.data!;

            return Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final location = history[index];
                    final isMostRecent = index == 0;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ListTile(
                        leading: Icon(
                          isMostRecent ? Icons.fmd_good_rounded : Icons.location_on_outlined,
                          color: isMostRecent ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        title: Text(
                          'Lat: ${location.latitude.toStringAsFixed(5)}, Lng: ${location.longitude.toStringAsFixed(5)}',
                          style: TextStyle(fontWeight: isMostRecent ? FontWeight.bold : FontWeight.normal),
                        ),
                        subtitle: Text(_formatDateTime(location.timestamp)),
                        // --- TRAILING MODIFICADO PARA SER UN BOTÓN ---
                        trailing: isMostRecent
                            ? ActionChip(
                          avatar: const Icon(Icons.directions_run, color: Colors.white, size: 16),
                          label: const Text('IR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _navigateToRouteToLastLocation(location),
                          backgroundColor: Colors.deepOrangeAccent,
                          elevation: 3,
                        )
                            : null,
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToCompleteRouteView,
                    icon: const Icon(Icons.timeline),
                    label: const Text('VER HISTORIAL COMPLETO EN MAPA'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            );
          }
          return const Center(child: Text('No hay datos disponibles.'));
        },
      ),
    );
  }
}
