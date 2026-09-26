import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../models/visit_session.dart';
import '../repositories/place_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/visit_repository.dart';
import 'habit_detection_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

class TrackingEngine extends ChangeNotifier {
  final PlaceRepository _placeRepository;
  final VisitRepository _visitRepository;
  final TripRepository _tripRepository;
  final LocationService _locationService;
  final NotificationService _notificationService;
  final HabitDetectionService _habitService;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _tickerTimer;
  Timer? _periodicCheckTimer;

  bool _isTrackingEnabled = true;
  bool get isTrackingEnabled => _isTrackingEnabled;

  bool _isTripTrackingEnabled = true;
  bool get isTripTrackingEnabled => _isTripTrackingEnabled;

  String _preferredMotorVehicle = TransportMode.auto;
  String get preferredMotorVehicle => _preferredMotorVehicle;

  double _activeTripMaxSpeedKmH = 0.0;
  double _activeTripMaxAcceleration = 0.0;
  String? _activeTripManualMode;

  Place? _currentPlace;
  Place? get currentPlace => _currentPlace;

  VisitSession? _activeVisit;
  VisitSession? get activeVisit => _activeVisit;

  Trip? _activeTrip;
  Trip? get activeTrip => _activeTrip;
  bool get isInTransit => _activeTrip != null && _currentPlace == null;

  List<TripPoint> _activeRoutePoints = [];
  List<TripPoint> get activeRoutePoints => List.unmodifiable(_activeRoutePoints);

  double _activeTripDistance = 0.0;
  double get activeTripDistance => _activeTripDistance;

  Position? _lastTripPointPosition;
  DateTime? _lastMovementTimestamp;

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  HabitDetectionService get habitService => _habitService;
  TripRepository get tripRepository => _tripRepository;

  TrackingEngine({
    PlaceRepository? placeRepository,
    VisitRepository? visitRepository,
    TripRepository? tripRepository,
    LocationService? locationService,
    NotificationService? notificationService,
    HabitDetectionService? habitDetectionService,
  })  : _placeRepository = placeRepository ?? PlaceRepository(),
        _visitRepository = visitRepository ?? VisitRepository(),
        _tripRepository = tripRepository ?? TripRepository(),
        _locationService = locationService ?? LocationService.instance,
        _notificationService = notificationService ?? NotificationService.instance,
        _habitService = habitDetectionService ?? HabitDetectionService.instance;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isTrackingEnabled = prefs.getBool('tracking_enabled') ?? true;
    _isTripTrackingEnabled = prefs.getBool('trip_tracking_enabled') ?? true;
    _preferredMotorVehicle = prefs.getString('preferred_motor_vehicle') ?? TransportMode.auto;

    await _habitService.initialize();

    // Check existing active visit from DB
    _activeVisit = await _visitRepository.getActiveVisit();
    if (_activeVisit != null) {
      _currentPlace = await _placeRepository.getPlaceById(_activeVisit!.placeId);
    }

    // Check existing active trip from DB
    _activeTrip = await _tripRepository.getActiveTrip();
    if (_activeTrip != null) {
      _activeRoutePoints = List.from(_activeTrip!.routePoints);
      _activeTripDistance = _activeTrip!.distanceMeters;
      if (_activeRoutePoints.isNotEmpty) {
        final last = _activeRoutePoints.last;
        _lastTripPointPosition = Position(
          longitude: last.longitude,
          latitude: last.latitude,
          timestamp: last.timestamp,
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: last.speed ?? 0.0,
          speedAccuracy: 0.0,
        );
      }
    }

    // Start timer for live counter updates (for ongoing visit and ongoing trip)
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeVisit != null || _activeTrip != null) {
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

  Future<void> setTripTrackingEnabled(bool enabled) async {
    _isTripTrackingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trip_tracking_enabled', enabled);
    notifyListeners();
  }

  Future<void> setPreferredMotorVehicle(String vehicle) async {
    _preferredMotorVehicle = vehicle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_motor_vehicle', vehicle);
    notifyListeners();
  }

  /// Classifies transport mode based on average speed, top speed, and acceleration kinetics.
  static String inferTransportMode({
    required double avgSpeedKmH,
    required double maxSpeedKmH,
    required double maxAccelerationMs2,
    required String preferredMotorVehicle,
  }) {
    // 1. Walking / Pedestrian (top speed < 7.5 km/h, avg < 6.5 km/h)
    if (maxSpeedKmH < 7.5 && avgSpeedKmH < 6.5) {
      return TransportMode.piedi;
    }

    // 2. Running vs brisk walking (max speed < 18.0 km/h, avg < 14.0 km/h)
    if (maxSpeedKmH < 18.0 && avgSpeedKmH < 14.0) {
      if (avgSpeedKmH > 6.8 || maxSpeedKmH > 9.5) {
        return TransportMode.corsa;
      }
      return TransportMode.piedi;
    }

    // 3. Bicycle (max speed < 38.0 km/h, avg < 22.0 km/h)
    if (maxSpeedKmH < 38.0 && avgSpeedKmH < 22.0) {
      return TransportMode.bici;
    }

    // 4. Motorized: Car vs Motorcycle / Scooter
    if (preferredMotorVehicle == TransportMode.moto) {
      return TransportMode.moto;
    }

    // Sharp acceleration bursts typical of motorcycles & scooters (>= 3.2 m/s²)
    if (maxAccelerationMs2 >= 3.2) {
      return TransportMode.moto;
    }

    return TransportMode.auto;
  }

  Future<void> updateTripTransportMode(Trip trip, String newMode) async {
    final updatedTrip = trip.copyWith(transportMode: newMode);
    await _tripRepository.insertTrip(updatedTrip);
    notifyListeners();
  }

  void updateActiveTripMode(String newMode) {
    if (_activeTrip == null) return;
    _activeTripManualMode = newMode;
    _activeTrip = _activeTrip!.copyWith(transportMode: newMode);
    notifyListeners();
  }

  Future<void> startMonitoring() async {
    await _positionSubscription?.cancel();
    _periodicCheckTimer?.cancel();

    // Check location right away
    await checkCurrentLocation();

    // Listen to GPS stream for movement (responsive 15-meter threshold)
    try {
      _positionSubscription = _locationService
          .getPositionStream(
            distanceFilterMeters: 15,
            accuracy: LocationAccuracy.high,
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

    // Backup periodic check every 2.5 minutes
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 150), (_) {
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
      // -------------------------------------------------------------
      // USER IS INSIDE A REGISTERED PLACE AREA
      // -------------------------------------------------------------
      await _habitService.onEnteredKnownPlace();

      if (_currentPlace?.id != matchedPlace.id) {
        // User just arrived at matchedPlace from outside or from another place!
        final previousPlace = _currentPlace;
        final previousVisit = _activeVisit;

        // 1. If there was a previous place with an active visit, close it
        if (previousPlace != null && previousVisit != null) {
          await _visitRepository.endActiveVisit();
        }

        // 2. If there was an active trip, finalize and record it!
        if (_activeTrip != null) {
          final now = DateTime.now();
          final durationSec = now.difference(_activeTrip!.startTime).inSeconds;

          _activeRoutePoints.add(TripPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: now,
            speed: position.speed,
          ));

          final avgSpeedKmH = durationSec > 10
              ? (_activeTripDistance / 1000.0) / (durationSec / 3600.0)
              : 0.0;

          final finalMode = _activeTripManualMode ??
              inferTransportMode(
                avgSpeedKmH: avgSpeedKmH,
                maxSpeedKmH: _activeTripMaxSpeedKmH,
                maxAccelerationMs2: _activeTripMaxAcceleration,
                preferredMotorVehicle: _preferredMotorVehicle,
              );

          final completedTrip = _activeTrip!.copyWith(
            destinationPlaceId: matchedPlace.id,
            destinationPlaceName: matchedPlace.name,
            endTime: now,
            durationSeconds: durationSec,
            distanceMeters: _activeTripDistance,
            transportMode: finalMode,
            routePoints: List.from(_activeRoutePoints),
          );

          // Save valid trip if distance >= 60m or duration >= 45s (filters boundary jitter)
          if (_activeTripDistance >= 60.0 || durationSec >= 45) {
            await _tripRepository.insertTrip(completedTrip);
            if (matchedPlace.notifyOnEntry) {
              await _notificationService.showTripCompletedNotification(
                destinationName: matchedPlace.name,
                formattedDistance: completedTrip.formattedDistance,
                formattedDuration: completedTrip.formattedDuration,
                originName: completedTrip.originPlaceName,
              );
            }
          } else if (matchedPlace.notifyOnEntry) {
            await _notificationService.showPlaceEntryNotification(
              placeName: matchedPlace.name,
              categoryName: matchedPlace.category.displayName,
            );
          }

          _activeTrip = null;
          _activeRoutePoints = [];
          _activeTripDistance = 0.0;
          _lastTripPointPosition = null;
          _activeTripMaxSpeedKmH = 0.0;
          _activeTripMaxAcceleration = 0.0;
          _activeTripManualMode = null;
        } else {
          // No active trip, standard place entry notification
          if (matchedPlace.notifyOnEntry) {
            await _notificationService.showPlaceEntryNotification(
              placeName: matchedPlace.name,
              categoryName: matchedPlace.category.displayName,
            );
          }
        }

        // 3. Start active visit for matchedPlace
        _currentPlace = matchedPlace;
        _activeVisit = await _visitRepository.startVisit(matchedPlace);
        _statusMessage = 'Sei a ${matchedPlace.name}';
      } else {
        // User is still within their current place: walking inside house or office!
        // No trip is recorded, no notifications are triggered.
        _statusMessage = 'Sei a ${matchedPlace.name}';
      }
    } else {
      // -------------------------------------------------------------
      // USER IS OUTSIDE ANY KNOWN REGISTERED PLACE AREA
      // -------------------------------------------------------------
      await _habitService.processUnregisteredLocation(position.latitude, position.longitude);

      if (_currentPlace != null && _activeVisit != null) {
        // USER JUST EXITED THE AREA!
        final leftPlace = _currentPlace!;
        final closedVisit = await _visitRepository.endActiveVisit();

        // 1. Notify area exit and trip start
        if (leftPlace.notifyOnExit) {
          await _notificationService.showAreaExitAndTripStartedNotification(
            placeName: leftPlace.name,
            formattedDuration: closedVisit?.formattedDuration,
          );
        }

        // 2. Start recording a new Trip
        if (_isTripTrackingEnabled) {
          final now = DateTime.now();
          final startPoint = TripPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: now,
            speed: position.speed,
          );
          final spd = position.speed > 0 ? position.speed : 0.0;
          final spdKmH = spd * 3.6;

          _activeRoutePoints = [startPoint];
          _activeTripDistance = 0.0;
          _lastTripPointPosition = position;
          _lastMovementTimestamp = now;
          _activeTripMaxSpeedKmH = spdKmH;
          _activeTripMaxAcceleration = 0.0;
          _activeTripManualMode = null;

          final initialMode = inferTransportMode(
            avgSpeedKmH: spdKmH,
            maxSpeedKmH: spdKmH,
            maxAccelerationMs2: 0.0,
            preferredMotorVehicle: _preferredMotorVehicle,
          );

          _activeTrip = Trip(
            originPlaceId: leftPlace.id,
            originPlaceName: leftPlace.name,
            startTime: now,
            distanceMeters: 0.0,
            transportMode: initialMode,
            routePoints: [startPoint],
          );
        }

        _currentPlace = null;
        _activeVisit = null;
        _statusMessage = 'In spostamento da ${leftPlace.name}';
      } else if (_activeTrip != null) {
        // USER IS CURRENTLY TRAVELING ON AN ACTIVE TRIP
        if (_lastTripPointPosition != null) {
          final delta = _locationService.calculateDistance(
            _lastTripPointPosition!.latitude,
            _lastTripPointPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (delta >= 15.0) {
            // Meaningful displacement: record point & accumulate distance
            _activeTripDistance += delta;

            final now = DateTime.now();
            final spd = position.speed > 0 ? position.speed : 0.0;
            final spdKmH = spd * 3.6;

            if (spdKmH > _activeTripMaxSpeedKmH) {
              _activeTripMaxSpeedKmH = spdKmH;
            }

            if (_lastTripPointPosition != null) {
              final dt = now.difference(_lastMovementTimestamp ?? now).inMilliseconds / 1000.0;
              if (dt > 0.5) {
                final lastSpd = (_lastTripPointPosition!.speed > 0) ? _lastTripPointPosition!.speed : 0.0;
                final dv = (spd - lastSpd).abs();
                final accel = dv / dt;
                if (accel > _activeTripMaxAcceleration && accel < 15.0) {
                  _activeTripMaxAcceleration = accel;
                }
              }
            }

            _lastTripPointPosition = position;
            _lastMovementTimestamp = now;

            final durSec = now.difference(_activeTrip!.startTime).inSeconds;
            final avgSpd = durSec > 10
                ? (_activeTripDistance / 1000.0) / (durSec / 3600.0)
                : spdKmH;

            final detectedMode = _activeTripManualMode ??
                inferTransportMode(
                  avgSpeedKmH: avgSpd,
                  maxSpeedKmH: _activeTripMaxSpeedKmH,
                  maxAccelerationMs2: _activeTripMaxAcceleration,
                  preferredMotorVehicle: _preferredMotorVehicle,
                );

            _activeRoutePoints.add(TripPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: now,
              speed: position.speed,
            ));

            _activeTrip = _activeTrip!.copyWith(
              distanceMeters: _activeTripDistance,
              transportMode: detectedMode,
              routePoints: List.from(_activeRoutePoints),
            );

            _statusMessage = 'In spostamento (${_activeTrip!.formattedDistance})';
          } else {
            // Stationary check outside registered places
            final now = DateTime.now();
            if (_lastMovementTimestamp != null &&
                now.difference(_lastMovementTimestamp!).inMinutes >= 7 &&
                _activeTripDistance >= 80.0) {
              await _finalizeOngoingTripToIntermediateSpot(position);
            }
          }
        } else {
          _lastTripPointPosition = position;
          _lastMovementTimestamp = DateTime.now();
        }
      } else {
        // Outside without an active trip
        _statusMessage = 'In movimento / Fuori zona';
      }
    }

    notifyListeners();
  }

  Future<void> _finalizeOngoingTripToIntermediateSpot(Position position) async {
    if (_activeTrip == null) return;
    final now = DateTime.now();
    final dur = now.difference(_activeTrip!.startTime).inSeconds;
    final avgSpeedKmH = dur > 10
        ? (_activeTripDistance / 1000.0) / (dur / 3600.0)
        : 0.0;

    final finalMode = _activeTripManualMode ??
        inferTransportMode(
          avgSpeedKmH: avgSpeedKmH,
          maxSpeedKmH: _activeTripMaxSpeedKmH,
          maxAccelerationMs2: _activeTripMaxAcceleration,
          preferredMotorVehicle: _preferredMotorVehicle,
        );

    final completedTrip = _activeTrip!.copyWith(
      destinationPlaceName: 'Sosta fuori zona',
      endTime: now,
      durationSeconds: dur,
      distanceMeters: _activeTripDistance,
      transportMode: finalMode,
      routePoints: List.from(_activeRoutePoints),
    );

    await _tripRepository.insertTrip(completedTrip);
    _activeTrip = null;
    _activeRoutePoints = [];
    _activeTripDistance = 0.0;
    _lastTripPointPosition = null;
    _activeTripMaxSpeedKmH = 0.0;
    _activeTripMaxAcceleration = 0.0;
    _activeTripManualMode = null;
    _statusMessage = 'Sosta fuori zona';
    notifyListeners();
  }

  /// Allows manual finish of an active trip from UI
  Future<void> manualFinishTrip() async {
    if (_activeTrip == null) return;
    final now = DateTime.now();
    final dur = now.difference(_activeTrip!.startTime).inSeconds;
    final avgSpeedKmH = dur > 10
        ? (_activeTripDistance / 1000.0) / (dur / 3600.0)
        : 0.0;

    final finalMode = _activeTripManualMode ??
        inferTransportMode(
          avgSpeedKmH: avgSpeedKmH,
          maxSpeedKmH: _activeTripMaxSpeedKmH,
          maxAccelerationMs2: _activeTripMaxAcceleration,
          preferredMotorVehicle: _preferredMotorVehicle,
        );

    final completedTrip = _activeTrip!.copyWith(
      destinationPlaceName: 'Destinazione raggiunta',
      endTime: now,
      durationSeconds: dur,
      distanceMeters: _activeTripDistance,
      transportMode: finalMode,
      routePoints: List.from(_activeRoutePoints),
    );

    if (_activeTripDistance >= 50.0 || dur >= 30) {
      await _tripRepository.insertTrip(completedTrip);
    }

    _activeTrip = null;
    _activeRoutePoints = [];
    _activeTripDistance = 0.0;
    _lastTripPointPosition = null;
    _activeTripMaxSpeedKmH = 0.0;
    _activeTripMaxAcceleration = 0.0;
    _activeTripManualMode = null;
    _statusMessage = 'Tragitto completato';
    notifyListeners();
  }

  /// Allows manual start of a trip from UI (e.g. when outside known places)
  Future<void> startManualTrip({String? originName}) async {
    if (_activeTrip != null) return;

    if (_activeVisit != null) {
      await _visitRepository.endActiveVisit();
      _activeVisit = null;
      _currentPlace = null;
    }

    final now = DateTime.now();
    Position? position = _lastKnownPosition;
    try {
      position ??= await _locationService.getCurrentPosition();
    } catch (_) {}

    TripPoint? startPoint;
    double spdKmH = 0.0;
    if (position != null) {
      _lastKnownPosition = position;
      _lastTripPointPosition = position;
      final spd = position.speed > 0 ? position.speed : 0.0;
      spdKmH = spd * 3.6;
      startPoint = TripPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: now,
        speed: position.speed,
      );
    }

    _activeRoutePoints = startPoint != null ? [startPoint] : [];
    _activeTripDistance = 0.0;
    _lastMovementTimestamp = now;
    _activeTripMaxSpeedKmH = spdKmH;
    _activeTripMaxAcceleration = 0.0;
    _activeTripManualMode = null;

    final initialMode = inferTransportMode(
      avgSpeedKmH: spdKmH,
      maxSpeedKmH: spdKmH,
      maxAccelerationMs2: 0.0,
      preferredMotorVehicle: _preferredMotorVehicle,
    );

    _activeTrip = Trip(
      originPlaceId: null,
      originPlaceName: originName ?? 'Posizione corrente',
      startTime: now,
      distanceMeters: 0.0,
      transportMode: initialMode,
      routePoints: _activeRoutePoints,
    );

    _statusMessage = 'Tragitto avviato';
    notifyListeners();
  }

  /// Allows manual check-in from UI
  Future<void> manualCheckIn(Place place) async {
    if (_currentPlace?.id == place.id) return;

    if (_activeTrip != null) {
      await manualFinishTrip();
    }

    if (_currentPlace != null) {
      await _visitRepository.endActiveVisit();
    }

    await _habitService.onEnteredKnownPlace();
    _currentPlace = place;
    _activeVisit = await _visitRepository.startVisit(place);
    _statusMessage = 'Check-in manuale a ${place.name}';
    notifyListeners();
  }

  /// Allows manual check-out from UI
  Future<void> manualCheckOut() async {
    if (_activeVisit != null) {
      final leftPlace = _currentPlace;
      await _visitRepository.endActiveVisit();
      _currentPlace = null;
      _activeVisit = null;

      // Start trip if leaving
      if (leftPlace != null && _isTripTrackingEnabled && _lastKnownPosition != null) {
        final now = DateTime.now();
        final spd = _lastKnownPosition!.speed > 0 ? _lastKnownPosition!.speed : 0.0;
        final spdKmH = spd * 3.6;
        final startPoint = TripPoint(
          latitude: _lastKnownPosition!.latitude,
          longitude: _lastKnownPosition!.longitude,
          timestamp: now,
          speed: _lastKnownPosition!.speed,
        );
        _activeRoutePoints = [startPoint];
        _activeTripDistance = 0.0;
        _lastTripPointPosition = _lastKnownPosition;
        _lastMovementTimestamp = now;
        _activeTripMaxSpeedKmH = spdKmH;
        _activeTripMaxAcceleration = 0.0;
        _activeTripManualMode = null;

        final initialMode = inferTransportMode(
          avgSpeedKmH: spdKmH,
          maxSpeedKmH: spdKmH,
          maxAccelerationMs2: 0.0,
          preferredMotorVehicle: _preferredMotorVehicle,
        );

        _activeTrip = Trip(
          originPlaceId: leftPlace.id,
          originPlaceName: leftPlace.name,
          startTime: now,
          distanceMeters: 0.0,
          transportMode: initialMode,
          routePoints: [startPoint],
        );
        _statusMessage = 'In spostamento da ${leftPlace.name}';
      } else {
        _statusMessage = 'Check-out completato';
      }
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
