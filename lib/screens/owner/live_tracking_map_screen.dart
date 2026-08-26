import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';

class LiveTrackingMapScreen extends StatefulWidget {
  const LiveTrackingMapScreen({super.key});

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _activeLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;

    if (companyId != null) {
      final data = await _api.getAllActiveTrackingLocations(
        companyId.toString(),
      );
      if (mounted) {
        setState(() {
          _activeLocations = data;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng center = const LatLng(13.0827, 80.2707); // Default Chennai
    if (_activeLocations.isNotEmpty) {
      try {
        final first = _activeLocations.first;
        center = LatLng(
          double.parse(first['latitude']),
          double.parse(first['longitude']),
        );
      } catch (e) {
        print("Parsing LatLng error: $e");
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Employees"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Map",
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchLocations();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeLocations.isEmpty
          ? const Center(
              child: Text(
                "No staff currently active in live tracking.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nmspayroll.face_attendance_app',
                ),
                MarkerLayer(
                  markers: _activeLocations.map((loc) {
                    double lat = 0.0;
                    double lng = 0.0;
                    try {
                      lat = double.parse(loc['latitude']);
                      lng = double.parse(loc['longitude']);
                    } catch (e) {
                      lat = 13.0827; // Error fail-safe
                      lng = 80.2707;
                    }

                    // Display a neat avatar and icon showing their name
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 80,
                      height: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.deepPurple),
                              boxShadow: const [
                                BoxShadow(blurRadius: 2, color: Colors.black26),
                              ],
                            ),
                            child: Text(
                              loc['name'].toString().split(' ').first,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.location_pin,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
