import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/place.dart';
import '../models/visit_session.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// Top-level callback required by native_geofence to run in background isolates
/// even when the application is completely closed or killed.
@pragma('vm:entry-point')
Future<void> tempoGeofenceCallback(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(
    '[NativeGeofence] Triggered: ${params.event.name} for ${params.geofences.length} geofence(s)',
  );

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('tracking_enabled') ?? true)) return;
    final dbService = DatabaseService.instance;
    final notifService = NotificationService.instance;

    for (final geofence in params.geofences) {
      final place = await dbService.getPlaceById(geofence.id);
      if (place == null || !place.isTrackingEnabled) continue;

      if (params.event == GeofenceEvent.enter) {
        final activeVisit = await dbService.getActiveVisit();
        // If already in this place, do not duplicate
        if (activeVisit != null && activeVisit.placeId == place.id) {
          continue;
        }

        final now = DateTime.now();

        // Close any prior active visit in another place
        if (activeVisit != null && activeVisit.placeId != place.id) {
          final dur = now.difference(activeVisit.startTime).inSeconds;
          await dbService.updateVisit(
            activeVisit.copyWith(endTime: now, durationSeconds: dur),
          );
        }

        // Close any ongoing active trip in DB
        final activeTrip = await dbService.getActiveTrip();
        if (activeTrip != null) {
          final tripDur = now.difference(activeTrip.startTime).inSeconds;
          await dbService.insertTrip(
            activeTrip.copyWith(
              endTime: now,
              durationSeconds: tripDur,
              destinationPlaceId: place.id,
              destinationPlaceName: place.name,
            ),
          );
        }

        // Insert new visit session for this place
        final newVisit = VisitSession(
          id: const Uuid().v4(),
          placeId: place.id,
          placeName: place.name,
          category: place.category,
          startTime: now,
          endTime: null,
        );
        await dbService.insertVisit(newVisit);

        // Fire entry notification
        if (place.notifyOnEntry) {
          await notifService.showPlaceEntryNotification(
            placeName: place.name,
            categoryName: place.category.displayName,
          );
        }
      } else if (params.event == GeofenceEvent.exit) {
        final activeVisit = await dbService.getActiveVisit();
        if (activeVisit != null && activeVisit.placeId == place.id) {
          final now = DateTime.now();
          final durationSec = now.difference(activeVisit.startTime).inSeconds;
          final closedVisit = activeVisit.copyWith(
            endTime: now,
            durationSeconds: durationSec,
          );
          await dbService.updateVisit(closedVisit);

          // Fire exit notification
          if (place.notifyOnExit) {
            await notifService.showAreaExitAndTripStartedNotification(
              placeName: place.name,
              formattedDuration: closedVisit.formattedDuration,
            );
          }
        }
      }
    }
  } catch (e, stack) {
    debugPrint('[NativeGeofence] Callback error: $e\n$stack');
  }
}

class NativeGeofenceService {
  static final NativeGeofenceService instance = NativeGeofenceService._();
  NativeGeofenceService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final bgPermission = await Permission.locationAlways.status;
      if (!bgPermission.isGranted) {
        debugPrint(
          '[NativeGeofence] Background location permission not granted. Skipping initialization.',
        );
        return;
      }
      await NativeGeofenceManager.instance.initialize();
      try {
        await NativeGeofenceManager.instance.reCreateAfterReboot();
      } catch (_) {}
      _isInitialized = true;
      debugPrint('[NativeGeofence] Initialized successfully');
    } catch (e) {
      debugPrint('[NativeGeofence] Initialization error: $e');
    }
  }

  Future<void> syncAllPlaces(List<Place> places) async {
    try {
      final bgPermission = await Permission.locationAlways.status;
      if (!bgPermission.isGranted) {
        debugPrint(
          '[NativeGeofence] Background location not granted, skipping sync.',
        );
        return;
      }
      if (!_isInitialized) await initialize();
      if (!_isInitialized) return;

      await NativeGeofenceManager.instance.removeAllGeofences();

      for (final place in places) {
        if (place.isTrackingEnabled) {
          await registerPlace(place);
        }
      }
      debugPrint(
        '[NativeGeofence] Synchronized ${places.length} places with OS geofencing',
      );
    } catch (e) {
      debugPrint('[NativeGeofence] Error syncing places: $e');
    }
  }

  Future<void> registerPlace(Place place) async {
    try {
      final bgPermission = await Permission.locationAlways.status;
      if (!bgPermission.isGranted) {
        debugPrint(
          '[NativeGeofence] Background location not granted, cannot register place ${place.name}.',
        );
        return;
      }
      if (!_isInitialized) await initialize();
      if (!_isInitialized) return;

      if (!place.isTrackingEnabled) {
        await removePlace(place.id);
        return;
      }

      final geofence = Geofence(
        id: place.id,
        location: Location(
          latitude: place.latitude,
          longitude: place.longitude,
        ),
        radiusMeters: place.radiusInMeters.clamp(50.0, 5000.0),
        triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
        iosSettings: const IosGeofenceSettings(initialTrigger: true),
        androidSettings: const AndroidGeofenceSettings(
          initialTriggers: {GeofenceEvent.enter},
          notificationResponsiveness: Duration(seconds: 10),
          loiteringDelay: Duration(minutes: 1),
        ),
      );

      await NativeGeofenceManager.instance.createGeofence(
        geofence,
        tempoGeofenceCallback,
      );
      debugPrint(
        '[NativeGeofence] Registered OS geofence for: ${place.name} (${place.radiusInMeters}m)',
      );
    } catch (e) {
      debugPrint(
        '[NativeGeofence] Failed to register geofence for ${place.name}: $e',
      );
    }
  }

  Future<void> removePlace(String placeId) async {
    if (!_isInitialized) return;
    try {
      await NativeGeofenceManager.instance.removeGeofenceById(placeId);
      debugPrint('[NativeGeofence] Removed OS geofence for: $placeId');
    } catch (e) {
      debugPrint('[NativeGeofence] Failed to remove geofence $placeId: $e');
    }
  }
}
