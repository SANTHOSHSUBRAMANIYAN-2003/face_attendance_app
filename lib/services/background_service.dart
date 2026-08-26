import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'api_service.dart';
import 'fcm_sender_service.dart';
import 'local_database_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bneeds_tracking',
    'Location Tracking Active',
    description: 'Pinging location every 2 minutes',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Don't autoStart on app boot without granted location permissions
      isForegroundMode: true,
      notificationChannelId: 'bneeds_tracking',
      initialNotificationTitle: 'Location Tracking Active',
      initialNotificationContent: 'Pinging location every 2 minutes',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  // Listen for explicit stop command
  service.on('stopService').listen((event) async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    service.stopSelf();
  });

  // Keep the isolate alive
  final completer = Completer<void>();
  
  // Enable wakelock safely inside background isolate
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  Future<void> performLocationPing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final isTrackingActive = prefs.getBool('is_tracking_active') ?? false;
      if (!isTrackingActive) {
        try {
          await WakelockPlus.disable();
        } catch (_) {}
        service.stopSelf();
        return;
      }

      final staffId = prefs.getString('tracking_staff_id');
      final companyId = prefs.getString('tracking_company_id');

      if (staffId == null || companyId == null) return;

      bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final api = ApiService();
      print("DEBUG: Background timer pinging location for staffId: $staffId -> Lat: ${position.latitude}, Long: ${position.longitude}");
      
      // Update backend server location
      final success = await api.updateLiveLocation(
        staffId,
        companyId,
        position.latitude.toString(),
        position.longitude.toString(),
      );

      // If updateLiveLocation returns false (e.g., owner turned off tracking on backend), stop tracking!
      if (!success) {
        print("DEBUG: updateLiveLocation returned false (Owner may have disabled tracking). Stopping background tracking.");
        await prefs.setBool('is_tracking_active', false);
        try {
          await WakelockPlus.disable();
        } catch (_) {}
        service.stopSelf();
        return;
      }

      // Perform local geofence & distance calculation on staff device
      double minDistance = double.infinity;
      String assignedLocationName = "No Assigned Location";
      bool breachedGeofence = false;

      try {
        final assignments = await api.getFieldAssignments(companyId, staffId: staffId);
        if (assignments.isNotEmpty) {
          for (var item in assignments) {
            double? targetLat = double.tryParse(item['fieldlat']?.toString() ?? '');
            double? targetLong = double.tryParse(item['fieldlong']?.toString() ?? '');
            if (targetLat != null && targetLong != null) {
              double distInMeters = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                targetLat,
                targetLong,
              );

              if (distInMeters < minDistance) {
                minDistance = distInMeters;
                assignedLocationName = item['fieldname']?.toString() ?? 'Field Site';
              }

              // Trigger if staff is more than 100 meters away from assigned field site
              if (distInMeters > 100) {
                breachedGeofence = true;
              }
            }
          }
        }
      } catch (e) {
        print("Geofence calculation error: $e");
      }

      final distToSave = minDistance == double.infinity ? 0.0 : minDistance;

      // 1. Store location logs locally on staff device in SQLite DB
      await LocalDatabaseService.insertLocationLog(
        staffId: staffId,
        companyId: companyId,
        latitude: position.latitude,
        longitude: position.longitude,
        distanceFromAssigned: distToSave,
        assignedLocationName: assignedLocationName,
        breachedGeofence: breachedGeofence,
      );

      // 2. If distance > 100 meters, trigger Firebase FCM notification directly to Owner:
      // FIRST notification sent IMMEDIATELY upon breach, subsequent notifications sent every 15 minutes.
      if (breachedGeofence) {
        final lastNotifyMs = prefs.getInt('last_fcm_breach_notify_time') ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final elapsedMinutes = (nowMs - lastNotifyMs) / (1000 * 60);

        final isFirstNotification = (lastNotifyMs == 0);

        if (isFirstNotification || elapsedMinutes >= 15) {
          final staffName = prefs.getString('tracking_staff_name') ?? 'Staff ($staffId)';
          print("Geofence breach detected! Distance: ${distToSave.toStringAsFixed(1)}m > 100m. ${isFirstNotification ? 'Sending FIRST notification immediately!' : 'Elapsed: ${elapsedMinutes.toStringAsFixed(1)} mins >= 15 mins.'} Sending FCM notification to owner...");
          
          await FcmSenderService.notifyOwner(
            companyId: companyId,
            title: "Geofence Breach Alert",
            body: "$staffName is ${distToSave.toStringAsFixed(0)} meters away from assigned site ($assignedLocationName).",
            dataPayload: {
              "staff_id": staffId,
              "company_id": companyId,
              "latitude": position.latitude.toString(),
              "longitude": position.longitude.toString(),
              "distance": distToSave.toStringAsFixed(1),
            },
          );

          await prefs.setInt('last_fcm_breach_notify_time', nowMs);
        } else {
          print("Geofence breach detected, but notification throttled. Next notification allowed in ${(15 - elapsedMinutes).toStringAsFixed(1)} mins.");
        }
      } else {
        // Reset timer when staff returns within geofence range
        if (prefs.containsKey('last_fcm_breach_notify_time')) {
          await prefs.remove('last_fcm_breach_notify_time');
        }
      }
    } catch (e) {
      print("Background location error: $e");
    }
  }

  // Execute initial location ping immediately upon start
  await performLocationPing();

  // Periodic location ping every 2 minutes
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final isTrackingActive = prefs.getBool('is_tracking_active') ?? false;
    if (!isTrackingActive) {
      timer.cancel();
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      completer.complete();
      service.stopSelf();
      return;
    }

    await performLocationPing();
  });

  await completer.future;
}
