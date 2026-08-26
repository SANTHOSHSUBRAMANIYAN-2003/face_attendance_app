import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';

class ActiveTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> staffDetails;

  const ActiveTrackingScreen({super.key, required this.staffDetails});

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen> {
  final ApiService _api = ApiService();
  bool _isStarting = true;
  String _statusMessage = "Initializing tracking...";
  Timer? _statusCheckTimer;
  Timer? _locationPingTimer;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so the screen is fully rendered
    // before we try to show the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTracking();
    });
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _locationPingTimer?.cancel();
    super.dispose();
  }

  /// Periodically ping location every 2 minutes while screen is active in foreground
  void _startForegroundLocationTimer() {
    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final companyId = Provider.of<SessionProvider>(
          context,
          listen: false,
        ).currentUser?.companyId;
        final staffId = widget.staffDetails['staffid'].toString();

        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        debugPrint("DEBUG: ActiveTrackingScreen 2-min ping for staff $staffId");

        final success = await _api.updateLiveLocation(
          staffId,
          companyId.toString(),
          position.latitude.toString(),
          position.longitude.toString(),
        );

        if (!success && mounted) {
          timer.cancel();
          _statusCheckTimer?.cancel();
          WakelockPlus.disable();
          final messenger = ScaffoldMessenger.of(context);
          final nav = Navigator.of(context);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_tracking_active', false);
          
          final bgService = FlutterBackgroundService();
          if (await bgService.isRunning()) {
            bgService.invoke("stopService");
          }

          messenger.showSnackBar(
            const SnackBar(
              content: Text("Live tracking stopped by employer."),
              backgroundColor: Colors.orange,
            ),
          );
          nav.pop();
        }
      } catch (e) {
        debugPrint("Foreground location ping error: $e");
      }
    });
  }

  /// Periodically check if Owner turned off tracking on server/shared preferences
  void _startOwnerStatusMonitoring() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final isActive = prefs.getBool('is_tracking_active') ?? false;
      if (!isActive && mounted) {
        timer.cancel();
        _locationPingTimer?.cancel();
        WakelockPlus.disable();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Live tracking stopped by employer."),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  /// Google Play: Prominent Disclosure dialog for BACKGROUND location access
  Future<bool> _showLocationDisclosure() async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(child: Text("Background Location")),
          ],
        ),
        content: const Text(
          "This app collects your GPS location in the background while Live Tracking is active.\n\n"
          "• Your location is saved locally and checked every 2 minutes.\n"
          "• It is visible only to your company administrator.\n"
          "• Tracking automatically stops when your employer ends the session.\n"
          "• Location data is not shared with any third parties.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text("I Agree & Continue"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  Future<void> _startTracking() async {
    // 0. Show Prominent Disclosure FIRST (Google Play requirement for background location)
    final agreed = await _showLocationDisclosure();
    if (!agreed) {
      if (mounted) {
        setState(() {
          _statusMessage = "Location access is required for live tracking.";
          _isStarting = false;
        });
      }
      return;
    }

    // 1. Check if GPS service is ON
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _statusMessage = "Location Services are OFF. Opening settings...";
          _isStarting = false;
        });
        // Open device location settings so user can turn GPS on
        await Geolocator.openLocationSettings();
      }
      return;
    }

    // 2. Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _statusMessage =
                "Location permission was denied. Please allow it to use tracking.";
            _isStarting = false;
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _statusMessage =
              "Location permission is permanently denied. Opening app settings...";
          _isStarting = false;
        });
        // Open app settings so user can manually grant the permission
        await Geolocator.openAppSettings();
      }
      return;
    }

    if (!mounted) return;

    // 2. Start tracking in the backend
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;

    final staffId = widget.staffDetails['staffid'].toString();

    final success = await _api.toggleTracking(
      staffId,
      companyId.toString(),
      'START',
    );

    if (mounted) {
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tracking_staff_id', staffId);
        await prefs.setString('tracking_company_id', companyId.toString());
        await prefs.setBool('is_tracking_active', true);
        
        WakelockPlus.enable(); // Keep awake while tracking is active

        // Trigger background service for 2-minute live location pings
        final bgService = FlutterBackgroundService();
        if (!await bgService.isRunning()) {
          await bgService.startService();
        }

        // Fetch and send INITIAL location immediately
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          await _api.updateLiveLocation(
            staffId,
            companyId.toString(),
            position.latitude.toString(),
            position.longitude.toString(),
          );
        } catch (e) {
          debugPrint("Failed initial location push: $e");
        }

        setState(() {
          _statusMessage = "Tracking active!";
          _isStarting = false;
        });

        // Start 2-minute foreground periodic location updates
        _startForegroundLocationTimer();

        // Monitor if owner stops tracking
        _startOwnerStatusMonitoring();
      } else {
        setState(() {
          _statusMessage = "Failed to start tracking on server.";
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _stopTracking() async {
    _statusCheckTimer?.cancel();
    _locationPingTimer?.cancel();
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;
    final staffId = widget.staffDetails['staffid'].toString();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final success = await _api.toggleTracking(
      staffId,
      companyId.toString(),
      'STOP',
    );

    if (mounted) {
      nav.pop(); // Dismiss loading
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tracking_staff_id');
        await prefs.remove('tracking_company_id');
        await prefs.setBool('is_tracking_active', false);
        
        WakelockPlus.disable(); // Release wakelock when stopped

        // Stop background service
        final bgService = FlutterBackgroundService();
        if (await bgService.isRunning()) {
          bgService.invoke("stopService");
        }

        messenger.showSnackBar(const SnackBar(content: Text("Tracking Stopped")));
        nav.pop(); // Go back to attendance screen
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text("Failed to stop tracking")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Don't let them easily swipe back
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade50, Colors.white],
          ),
        ),
        child: _isStarting
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16, color: Colors.indigo),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Map Pin Animation (Using a static icon with pulsing effect usually, but we keep it simple here)
                  Icon(
                    Icons.location_on,
                    size: 100,
                    color: Colors.indigo.shade600,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Hello, ${widget.staffDetails['name']}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      "Your location is actively being logged and checked every 2 minutes.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "Please do not force-close or kill this app. You can minimize it and it will run in the background.",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 5,
                      ),
                      onPressed: _stopTracking,
                      icon: const Icon(Icons.stop_circle_outlined, size: 28),
                      label: const Text(
                        "Stop Tracking",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
