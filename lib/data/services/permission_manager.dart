import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../repositories/place_repository.dart';
import 'native_geofence_service.dart';

class PermissionStatusState {
  final bool locationGranted;
  final bool backgroundLocationGranted;
  final bool notificationGranted;
  final bool batteryOptimizationIgnored;

  const PermissionStatusState({
    required this.locationGranted,
    required this.backgroundLocationGranted,
    required this.notificationGranted,
    required this.batteryOptimizationIgnored,
  });

  bool get isAllGranted =>
      locationGranted &&
      backgroundLocationGranted &&
      notificationGranted &&
      batteryOptimizationIgnored;
}

class PermissionManager {
  static final PermissionManager instance = PermissionManager._init();
  PermissionManager._init();

  Future<PermissionStatusState> checkAllStatus() async {
    final loc = await Permission.location.status;
    final bgLoc = await Permission.locationAlways.status;
    final notif = await Permission.notification.status;
    final battery = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : PermissionStatus.granted;

    return PermissionStatusState(
      locationGranted: loc.isGranted,
      backgroundLocationGranted: bgLoc.isGranted,
      notificationGranted: notif.isGranted,
      batteryOptimizationIgnored: battery.isGranted,
    );
  }

  /// Request foreground location
  Future<bool> requestForegroundLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request background location ("Consenti sempre")
  Future<bool> requestBackgroundLocation(BuildContext context) async {
    // Ensure foreground is granted first
    final locStatus = await Permission.location.status;
    if (!locStatus.isGranted) {
      final req = await Permission.location.request();
      if (!req.isGranted) return false;
    }

    // Attempt background request
    final bgStatus = await Permission.locationAlways.request();
    if (bgStatus.isGranted) {
      await _syncGeofencesIfGranted();
      return true;
    }

    // On Android 11+ and Samsung OneUI, background permission requires manual selection in Settings
    if (context.mounted) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.location_on_rounded, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text('Posizione in Background', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text(
            'Per rilevare l\'arrivo e l\'uscita dai tuoi luoghi a schermo spento, su Android e Samsung è necessario selezionare:\n\n'
            '👉 "Consenti sempre" (o "Consenti sempre nella posizione").\n\n'
            'Tocca il pulsante qui sotto per aprire direttamente le impostazioni dei permessi.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Più tardi'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apri Impostazioni'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        await openAppSettings();
      }
    }

    final recheck = await Permission.locationAlways.status;
    if (recheck.isGranted) {
      await _syncGeofencesIfGranted();
    }
    return recheck.isGranted;
  }

  Future<void> _syncGeofencesIfGranted() async {
    try {
      final status = await Permission.locationAlways.status;
      if (status.isGranted) {
        final places = await PlaceRepository().getAllPlaces();
        await NativeGeofenceService.instance.syncAllPlaces(places);
      }
    } catch (e) {
      debugPrint('Error syncing geofences after permission granted: $e');
    }
  }

  /// Request notification permission
  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request battery optimization disable (Crucial for Samsung OneUI)
  Future<bool> requestBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Interactive step-by-step setup that guides Samsung/Android users through all permissions
  Future<PermissionStatusState> runFullSetupWizard(BuildContext context) async {
    // 1. Foreground Location
    await requestForegroundLocation();

    // 2. Background Location
    if (context.mounted) {
      await requestBackgroundLocation(context);
    }

    // 3. Notifications
    await requestNotifications();

    // 4. Battery Optimization
    await requestBatteryOptimization();

    return await checkAllStatus();
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
