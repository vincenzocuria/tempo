import 'dart:async';
import 'package:flutter/widgets.dart';
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

class TrackingEngine extends ChangeNotifier with WidgetsBindingObserver {
  final PlaceRepository _placeRepository;
  final VisitRepository _visitRepository;
  final TripRepository _tripRepository;
  final LocationService _locationService;
  final NotificationService _notificationService;
  final HabitDetectionService _habitService;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _tickerTimer;
  Timer? _periodicCheckTimer;
  bool _isDisposed = false;

  int _activeDistanceFilter = 15;
  int get activeDistanceFilter => _activeDistanceFilter;

  LocationAccuracy _activeAccuracy = LocationAccuracy.high;
  LocationAccuracy get activeAccuracy => _activeAccuracy;

  bool _isTrackingEnabled = true;
  bool get isTrackingEnabled => _isTrackingEnabled;

  bool _isTripTrackingEnabled = true;
  bool get isTripTrackingEnabled => _isTripTrackingEnabled;

  String _preferredMotorVehicle = TransportMode.auto;
  String get preferredMotorVehicle => _preferredMotorVehicle;

  int _placesVersion = 0;
  int get placesVersion => _placesVersion;

  double _activeTripMaxSpeedKmH = 0.0;
  double _activeTripMaxAcceleration = 0.0;
  String? _activeTripManualMode;
  double _activeTripMaxDistanceFromOrigin = 0.0;
  String? _candidatePlaceId;
  int _candidatePlaceHits = 0;
  Position? _outsideAnchorPosition;
  DateTime? _outsideAnchorTime;

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
      final tripAge = DateTime.now().difference(_activeTrip!.startTime);
      if (tripAge.inHours >= 6) {
        // Stale trip from a long time ago: close it
        await _tripRepository.insertTrip(_activeTrip!.copyWith(
          endTime: _activeTrip!.startTime.add(Duration(seconds: _activeTrip!.durationSeconds.clamp(60, 3600))),
          destinationPlaceName: _activeTrip!.destinationPlaceName ?? 'Destinazione raggiunta',
        ));
        _activeTrip = null;
      } else {
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
    }

    // Register lifecycle observer for foreground-only ticker and power management
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}

    _startTicker();

    if (_isTrackingEnabled) {
      await startMonitoring();
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeVisit != null || _activeTrip != null) {
        notifyListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Pause 1-second ticker when app is in background to save CPU and battery
      _tickerTimer?.cancel();
      _tickerTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      // Resume ticker in foreground and sync state if native geofence triggered while away
      _startTicker();
      reloadActiveStateFromDb();
      notifyListeners();
    }
  }

  Future<void> reloadActiveStateFromDb() async {
    try {
      final active = await _visitRepository.getActiveVisit();
      if (_isDisposed) return;
      _activeVisit = active;
      if (_activeVisit != null) {
        _currentPlace = await _placeRepository.getPlaceById(_activeVisit!.placeId);
      } else {
        _currentPlace = null;
      }
      final trip = await _tripRepository.getActiveTrip();
      if (_isDisposed) return;
      _activeTrip = trip;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error reloading active state from db: $e');
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

    // Check location right away asynchronously so startup and UI are never blocked
    unawaited(checkCurrentLocation());

    // Determine initial adaptive profile and start stream
    _applyAdaptiveTrackingSettings(forceRestart: true);

    // Battery-optimized watchdog timer: check every 10 minutes instead of every 150 seconds
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final now = DateTime.now();
      // If we haven't received movement in 10 minutes, verify health without hammering GNSS hardware
      if (_lastMovementTimestamp == null || now.difference(_lastMovementTimestamp!).inMinutes >= 10) {
        final lastKnown = await _locationService.getLastKnownPosition();
        if (lastKnown != null && now.difference(lastKnown.timestamp).inMinutes < 10) {
          await _processNewPosition(lastKnown);
        } else {
          await checkCurrentLocation(
            accuracy: _currentPlace != null ? LocationAccuracy.medium : LocationAccuracy.high,
          );
        }
      }
    });
  }

  void _applyAdaptiveTrackingSettings({bool forceRestart = false}) {
    if (!_isTrackingEnabled) return;

    int targetFilter;
    LocationAccuracy targetAccuracy;

    if (_currentPlace != null) {
      // Stationary inside a known place: conserve battery!
      // Relax filter to 35m-70m and switch to medium accuracy (Wi-Fi/Cell assisted, low GNSS power)
      targetFilter = (_currentPlace!.radiusInMeters * 0.4).clamp(35.0, 70.0).round();
      targetAccuracy = LocationAccuracy.medium;
    } else if (_activeTrip != null) {
      // Active travel: high precision tracking
      targetFilter = 15;
      targetAccuracy = LocationAccuracy.high;
    } else {
      // Outside known place, scanning for entrance/departure
      targetFilter = 25;
      targetAccuracy = LocationAccuracy.high;
    }

    if (forceRestart || targetFilter != _activeDistanceFilter || targetAccuracy != _activeAccuracy) {
      _activeDistanceFilter = targetFilter;
      _activeAccuracy = targetAccuracy;
      _restartLocationStream();
    }
  }

  void _restartLocationStream() {
    if (!_isTrackingEnabled) return;
    _positionSubscription?.cancel();
    try {
      _positionSubscription = _locationService
          .getPositionStream(
            distanceFilterMeters: _activeDistanceFilter,
            accuracy: _activeAccuracy,
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
      debugPrint('Error restarting position stream: $e');
    }
  }

  Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  Future<void> checkCurrentLocation({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    if (_isChecking) return;
    _isChecking = true;
    notifyListeners();

    try {
      final pos = await _locationService.getCurrentPosition(accuracy: accuracy);
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

    // Check GPS accuracy: if accuracy is extremely poor (> 50m), avoid false geofence triggers
    final isAccurateFix = position.accuracy <= 0.0 || position.accuracy.isNaN || position.accuracy <= 50.0;

    Place? matchedPlace;
    double minDistance = double.infinity;

    if (isAccurateFix) {
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
    }

    // Protection against immediate false return to the origin place:
    if (matchedPlace != null && _currentPlace?.id != matchedPlace.id) {
      if (_activeTrip != null && matchedPlace.id == _activeTrip!.originPlaceId) {
        final elapsedTripSec = DateTime.now().difference(_activeTrip!.startTime).inSeconds;
        // User must have either reached beyond the outer perimeter buffer, traveled >= 180m, or been in transit >= 4 min
        final hasLeftPerimeter = _activeTripMaxDistanceFromOrigin >= (matchedPlace.radiusInMeters + 60.0) ||
            _activeTripDistance >= 180.0 ||
            elapsedTripSec >= 240;

        if (!hasLeftPerimeter) {
          // Still walking in vicinity of departure point: treat as transit, do NOT falsely conclude trip
          matchedPlace = null;
        }
      }
    }

    if (matchedPlace != null) {
      // -------------------------------------------------------------
      // USER IS INSIDE A REGISTERED PLACE AREA
      // -------------------------------------------------------------
      _outsideAnchorPosition = null;
      _outsideAnchorTime = null;

      await _habitService.onEnteredKnownPlace();

      if (_currentPlace?.id != matchedPlace.id) {
        // Debounce: require at least 2 consecutive stable GPS readings inside place before confirming arrival
        if (_candidatePlaceId == matchedPlace.id) {
          _candidatePlaceHits++;
        } else {
          _candidatePlaceId = matchedPlace.id;
          _candidatePlaceHits = 1;
        }

        if (_candidatePlaceHits < 2) {
          // Record ongoing movement on active trip while waiting for confirmation
          if (_activeTrip != null) {
            await _updateActiveTripProgress(position, places: places);
          }
          notifyListeners();
          return;
        }

        // Reset debounce counters upon confirmed arrival
        _candidatePlaceId = null;
        _candidatePlaceHits = 0;

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

          // Save valid trip if distance >= 50m or duration >= 30s
          if (_activeTripDistance >= 50.0 || durationSec >= 30) {
            await _tripRepository.insertTrip(completedTrip);
            if (matchedPlace.notifyOnEntry) {
              await _notificationService.showTripCompletedNotification(
                destinationName: matchedPlace.name,
                formattedDistance: completedTrip.formattedDistance,
                formattedDuration: completedTrip.formattedDuration,
                originName: completedTrip.originPlaceName,
              );
            }
          } else {
            // Very short boundary noise: clean up active trip from DB
            await _tripRepository.deleteTrip(completedTrip.id);
            if (matchedPlace.notifyOnEntry) {
              await _notificationService.showPlaceEntryNotification(
                placeName: matchedPlace.name,
                categoryName: matchedPlace.category.displayName,
              );
            }
          }

          _activeTrip = null;
          _activeRoutePoints = [];
          _activeTripDistance = 0.0;
          _lastTripPointPosition = null;
          _activeTripMaxSpeedKmH = 0.0;
          _activeTripMaxAcceleration = 0.0;
          _activeTripManualMode = null;
          _activeTripMaxDistanceFromOrigin = 0.0;
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
        _applyAdaptiveTrackingSettings();
      } else {
        // User is still within their current place: walking inside house or office!
        _candidatePlaceId = null;
        _candidatePlaceHits = 0;
        _statusMessage = 'Sei a ${matchedPlace.name}';
      }
    } else {
      // -------------------------------------------------------------
      // USER IS OUTSIDE ANY KNOWN REGISTERED PLACE AREA
      // -------------------------------------------------------------
      _candidatePlaceId = null;
      _candidatePlaceHits = 0;

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
          _activeTripMaxDistanceFromOrigin = 0.0;
          _outsideAnchorPosition = null;
          _outsideAnchorTime = null;

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
          await _tripRepository.insertTrip(_activeTrip!);
        }

        _currentPlace = null;
        _activeVisit = null;
        _statusMessage = 'In spostamento da ${leftPlace.name}';
        _applyAdaptiveTrackingSettings();
      } else if (_activeTrip != null) {
        // USER IS CURRENTLY TRAVELING ON AN ACTIVE TRIP
        await _updateActiveTripProgress(position, places: places);
      } else {
        // Outside without an active trip: auto-detect walking/moving displacement!
        if (_isTripTrackingEnabled) {
          if (_outsideAnchorPosition == null) {
            _outsideAnchorPosition = position;
            _outsideAnchorTime = DateTime.now();
          } else {
            final displacement = _locationService.calculateDistance(
              _outsideAnchorPosition!.latitude,
              _outsideAnchorPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            // As soon as user walks 25m or moves with speed >= 0.8 m/s over 15m
            if (displacement >= 25.0 || (position.speed > 0.8 && displacement >= 15.0)) {
              Place? nearbyPlace;
              double nearestDist = double.infinity;
              for (final p in activePlaces) {
                final d = _locationService.calculateDistance(
                  _outsideAnchorPosition!.latitude,
                  _outsideAnchorPosition!.longitude,
                  p.latitude,
                  p.longitude,
                );
                if (d < nearestDist && d <= (p.radiusInMeters + 120.0)) {
                  nearestDist = d;
                  nearbyPlace = p;
                }
              }

              final originName = nearbyPlace != null
                  ? nearbyPlace.name
                  : 'Inizio spostamento';

              await _startAutoTrip(
                originName: originName,
                originPlaceId: nearbyPlace?.id,
                startPosition: _outsideAnchorPosition!,
                currentPosition: position,
              );
            }
          }
        }
        _statusMessage = 'In movimento / Fuori zona';
      }
    }

    notifyListeners();
  }

  Future<void> _startAutoTrip({
    required String originName,
    String? originPlaceId,
    required Position startPosition,
    required Position currentPosition,
  }) async {
    if (_activeTrip != null || !_isTripTrackingEnabled) return;

    final now = DateTime.now();
    final startPt = TripPoint(
      latitude: startPosition.latitude,
      longitude: startPosition.longitude,
      timestamp: _outsideAnchorTime ?? now.subtract(const Duration(seconds: 15)),
      speed: startPosition.speed > 0 ? startPosition.speed : null,
    );
    final curPt = TripPoint(
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
      timestamp: now,
      speed: currentPosition.speed > 0 ? currentPosition.speed : null,
    );

    final dist = _locationService.calculateDistance(
      startPosition.latitude,
      startPosition.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    final spd = currentPosition.speed > 0 ? currentPosition.speed : 0.0;
    final spdKmH = spd * 3.6;

    final mode = inferTransportMode(
      avgSpeedKmH: spdKmH > 0 ? spdKmH : 4.0,
      maxSpeedKmH: spdKmH,
      maxAccelerationMs2: 0.0,
      preferredMotorVehicle: _preferredMotorVehicle,
    );

    _activeRoutePoints = [startPt, curPt];
    _activeTripDistance = dist;
    _lastTripPointPosition = currentPosition;
    _lastMovementTimestamp = now;
    _activeTripMaxSpeedKmH = spdKmH;
    _activeTripMaxAcceleration = 0.0;
    _activeTripManualMode = null;
    _activeTripMaxDistanceFromOrigin = dist;
    _outsideAnchorPosition = null;
    _outsideAnchorTime = null;

    _activeTrip = Trip(
      originPlaceId: originPlaceId,
      originPlaceName: originName,
      startTime: _outsideAnchorTime ?? now.subtract(const Duration(seconds: 15)),
      distanceMeters: dist,
      transportMode: mode,
      routePoints: _activeRoutePoints,
    );

    await _tripRepository.insertTrip(_activeTrip!);
    _statusMessage = 'In spostamento (${_activeTrip!.formattedDistance})';
    _applyAdaptiveTrackingSettings();
    notifyListeners();
  }

  Future<void> _updateActiveTripProgress(Position position, {List<Place>? places}) async {
    if (_activeTrip == null) return;

    // Track max displacement away from origin place
    if (_activeTrip!.originPlaceId != null && places != null) {
      final originPlace = places.where((p) => p.id == _activeTrip!.originPlaceId).firstOrNull;
      if (originPlace != null) {
        final dist = _locationService.calculateDistance(
          originPlace.latitude,
          originPlace.longitude,
          position.latitude,
          position.longitude,
        );
        if (dist > _activeTripMaxDistanceFromOrigin) {
          _activeTripMaxDistanceFromOrigin = dist;
        }
      }
    }

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

        if (_activeRoutePoints.length % 3 == 0 || _activeRoutePoints.length <= 3) {
          await _tripRepository.insertTrip(_activeTrip!);
        }

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
    _activeTripMaxDistanceFromOrigin = 0.0;
    _statusMessage = 'Sosta fuori zona';
    _applyAdaptiveTrackingSettings();
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
    _activeTripMaxDistanceFromOrigin = 0.0;
    _statusMessage = 'Tragitto completato';
    _applyAdaptiveTrackingSettings();
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
    _activeTripMaxDistanceFromOrigin = 0.0;

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
    await _tripRepository.insertTrip(_activeTrip!);

    _statusMessage = 'Tragitto avviato';
    _applyAdaptiveTrackingSettings();
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
    _applyAdaptiveTrackingSettings();
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
        _activeTripMaxDistanceFromOrigin = 0.0;

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
        await _tripRepository.insertTrip(_activeTrip!);
        _statusMessage = 'In spostamento da ${leftPlace.name}';
      } else {
        _statusMessage = 'Check-out completato';
      }
      _applyAdaptiveTrackingSettings();
      notifyListeners();
    }
  }

  /// Synchronizes active state when a place is renamed or its configuration is edited
  void onPlaceUpdated(Place place) {
    _placesVersion++;
    if (_currentPlace?.id == place.id) {
      _currentPlace = place;
      _statusMessage = 'All\'interno di ${place.name}';
    }
    if (_activeVisit?.placeId == place.id) {
      _activeVisit = _activeVisit!.copyWith(
        placeName: place.name,
        category: place.category,
      );
    }
    if (_activeTrip?.originPlaceId == place.id) {
      _activeTrip = _activeTrip!.copyWith(originPlaceName: place.name);
    }
    if (_activeTrip?.destinationPlaceId == place.id) {
      _activeTrip = _activeTrip!.copyWith(destinationPlaceName: place.name);
    }
    notifyListeners();
  }

  /// Cleans up state when a place is deleted
  void onPlaceDeleted(String placeId) {
    _placesVersion++;
    if (_currentPlace?.id == placeId) {
      _currentPlace = null;
      if (_activeVisit != null && _activeVisit!.placeId == placeId) {
        _visitRepository.endActiveVisit();
        _activeVisit = null;
      }
      _statusMessage = 'Fuori dai luoghi registrati';
      _applyAdaptiveTrackingSettings();
    }
    if (_activeTrip?.originPlaceId == placeId) {
      _activeTrip = _activeTrip!.copyWith(originPlaceId: null);
    }
    if (_activeTrip?.destinationPlaceId == placeId) {
      _activeTrip = _activeTrip!.copyWith(
        destinationPlaceId: null,
        destinationPlaceName: 'In spostamento',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _isDisposed = true;
    _tickerTimer?.cancel();
    _periodicCheckTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
