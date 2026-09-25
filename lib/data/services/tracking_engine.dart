import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../models/visit_session.dart';
import '../repositories/place_repository.dart';
import '../repositories/visit_repository.dart';
import 'location_service.dart';
import 'notification_service.dart';

class TrackingEngine extends ChangeNotifier {
  final PlaceRepository _placeRepository;
  final VisitRepository _visitRepository;
  final LocationService _locationService;
  final NotificationService _notificationService;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _tickerTimer;
  Timer? _periodicCheckTimer;

  bool _isTrackingEnabled = true;
  bool get isTrackingEnabled => _isTrackingEnabled;

  Place? _currentPlace;
  Place? get currentPlace => _currentPlace;

  VisitSession? _activeVisit;
  VisitSession? get activeVisit => _activeVisit;

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  TrackingEngine({
    PlaceRepository? placeRepository,
    VisitRepository? visitRepository,
    LocationService? locationService,
    NotificationService? notificationService,
  })  : _placeRepository = placeRepository ?? PlaceRepository(),
        _visitRepository = visitRepository ?? VisitRepository(),
        _locationService = locationService ?? LocationService.instance,
        _notificationService = notificationService ?? NotificationService.instance;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isTrackingEnabled = prefs.getBool('tracking_enabled') ?? true;

    // Check existing active visit from DB
    _activeVisit = await _visitRepository.getActiveVisit();
    if (_activeVisit != null) {
      _currentPlace = await _placeRepository.getPlaceById(_activeVisit!.placeId);
    }

    // Start timer for live counter updates
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeVisit != null) {
        notifyListeners();
      }
    });

    if (_isTrackingEnabled) {
      await startMonitoring();
    }
  }

  Future<void> setTrackingEnabled(bool enabled) async {
    _isTrackingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tracking_enabled', enabled);

    if (enabled) {
      await startMonitoring();
    } else {
      await stopMonitoring();
    }
    notifyListeners();
  }

  Future<void> startMonitoring() async {
    await _positionSubscription?.cancel();
    _periodicCheckTimer?.cancel();

    // Check location right away
    await checkCurrentLocation();

    // Listen to GPS stream for movement
    try {
      _positionSubscription = _locationService
          .getPositionStream(
            distanceFilterMeters: 25,
            accuracy: LocationAccuracy.medium,
          )
          .listen(
            (position) => _processNewPosition(position),
            onError: (err) {
              debugPrint('Location stream error: $err');
              _statusMessage = 'GPS non disponibile o permessi mancanti';
              notifyListeners();
            },
          );
    } catch (e) {
      debugPrint('Error starting position stream: $e');
    }

    // Backup periodic check every 3 minutes
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      checkCurrentLocation();
    });
  }

  Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  Future<void> checkCurrentLocation() async {
    if (_isChecking) return;
    _isChecking = true;
    notifyListeners();

    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null) {
        await _processNewPosition(pos);
      }
    } catch (e) {
      debugPrint('Error in checkCurrentLocation: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _processNewPosition(Position position) async {
    _lastKnownPosition = position;
    final places = await _placeRepository.getAllPlaces();
    final activePlaces = places.where((p) => p.isTrackingEnabled).toList();

    Place? matchedPlace;
    double minDistance = double.infinity;

    for (final place in activePlaces) {
      final distance = _locationService.calculateDistance(
        position.latitude,
        position.longitude,
        place.latitude,
        place.longitude,
      );

      // If user is currently in this place, apply 20m hysteresis buffer to prevent jitter
      final isCurrentlyHere = _currentPlace?.id == place.id;
      final effectiveRadius = isCurrentlyHere
          ? place.radiusInMeters + 20.0
          : place.radiusInMeters;

      if (distance <= effectiveRadius) {
        if (distance < minDistance) {
          minDistance = distance;
          matchedPlace = place;
        }
      }
    }

    if (matchedPlace != null) {
      // User is inside matchedPlace
      if (_currentPlace?.id != matchedPlace.id) {
        // Just arrived at matchedPlace!
        final previousPlace = _currentPlace;
        final previousVisit = _activeVisit;

        if (previousPlace != null && previousVisit != null) {
          // Closed previous
          final closed = await _visitRepository.endActiveVisit();
          if (previousPlace.notifyOnExit && closed != null) {
            await _notificationService.showPlaceExitNotification(
              placeName: previousPlace.name,
              formattedDuration: closed.formattedDuration,
            );
          }
        }

        _currentPlace = matchedPlace;
        _activeVisit = await _visitRepository.startVisit(matchedPlace);
        _statusMessage = 'Sei a ${matchedPlace.name}';

        if (matchedPlace.notifyOnEntry) {
          await _notificationService.showPlaceEntryNotification(
            placeName: matchedPlace.name,
            categoryName: matchedPlace.category.displayName,
          );
        }
      }
    } else {
      // User is outside any known place
      if (_currentPlace != null && _activeVisit != null) {
        // Left the place!
        final leftPlace = _currentPlace!;
        final closed = await _visitRepository.endActiveVisit();

        if (leftPlace.notifyOnExit && closed != null) {
          await _notificationService.showPlaceExitNotification(
            placeName: leftPlace.name,
            formattedDuration: closed.formattedDuration,
          );
        }

        _currentPlace = null;
        _activeVisit = null;
        _statusMessage = 'In movimento / Fuori zona';
      }
    }

    notifyListeners();
  }

  /// Allows manual check-in from UI
  Future<void> manualCheckIn(Place place) async {
    if (_currentPlace?.id == place.id) return;

    if (_currentPlace != null) {
      await _visitRepository.endActiveVisit();
    }

    _currentPlace = place;
    _activeVisit = await _visitRepository.startVisit(place);
    _statusMessage = 'Check-in manuale a ${place.name}';
    notifyListeners();
  }

  /// Allows manual check-out from UI
  Future<void> manualCheckOut() async {
    if (_activeVisit != null) {
      await _visitRepository.endActiveVisit();
      _currentPlace = null;
      _activeVisit = null;
      _statusMessage = 'Check-out completato';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _periodicCheckTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
