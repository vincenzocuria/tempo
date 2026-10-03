import '../../../data/services/session_time.dart';

import 'package:flutter/material.dart';

import '../../../data/models/trip.dart';
import '../../../data/models/visit_session.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/tracking_engine.dart';

class DashboardViewModel extends ChangeNotifier {
  final VisitRepository _visitRepository;
  final TripRepository _tripRepository;
  final TrackingEngine _trackingEngine;

  List<VisitSession> _todayVisits = [];
  List<VisitSession> get todayVisits => _todayVisits;

  List<Trip> _todayTrips = [];
  List<Trip> get todayTrips => _todayTrips;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Duration _totalTrackedToday = Duration.zero;
  Duration get totalTrackedToday => _totalTrackedToday;

  double _totalDistanceToday = 0.0;
  double get totalDistanceToday => _totalDistanceToday;

  Duration _totalTripDurationToday = Duration.zero;
  Duration get totalTripDurationToday => _totalTripDurationToday;

  String? _topPlaceToday;
  String? get topPlaceToday => _topPlaceToday;

  DashboardViewModel({
    required VisitRepository visitRepository,
    TripRepository? tripRepository,
    required TrackingEngine trackingEngine,
  }) : _visitRepository = visitRepository,
       _tripRepository = tripRepository ?? TripRepository(),
       _trackingEngine = trackingEngine {
    _trackingEngine.addListener(_onTrackingEngineUpdated);
    loadData();
  }

  String? _lastPlaceId;
  String? _lastVisitId;
  String? _lastTripId;
  int _lastPlacesVersion = 0;
  bool _disposed = false;
  DateTime? _loadedDay;
  bool _reloadPending = false;

  void _onTrackingEngineUpdated() {
    if (_disposed) return;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final currentPlaceId = _trackingEngine.currentPlace?.id;
    final currentVisitId = _trackingEngine.activeVisit?.id;
    final currentTripId = _trackingEngine.activeTrip?.id;
    final currentPlacesVersion = _trackingEngine.placesVersion;

    if (currentPlaceId != _lastPlaceId ||
        currentVisitId != _lastVisitId ||
        currentTripId != _lastTripId ||
        currentPlacesVersion != _lastPlacesVersion ||
        _loadedDay != day) {
      _lastPlaceId = currentPlaceId;
      _lastVisitId = currentVisitId;
      _lastTripId = currentTripId;
      _lastPlacesVersion = currentPlacesVersion;
      loadData();
      return;
    }
    _calculateTodayStats();
    notifyListeners();
  }

  Future<void> loadData() async {
    if (_disposed) return;
    if (_isLoading) {
      _reloadPending = true;
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      _todayVisits = await _visitRepository.getTodayVisits();
      _todayTrips = await _tripRepository.getTodayTrips();
      if (_disposed) return;
      final now = DateTime.now();
      _loadedDay = DateTime(now.year, now.month, now.day);
      _calculateTodayStats();
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
        if (_reloadPending) {
          _reloadPending = false;
          loadData();
        }
      }
    }
  }

  void _calculateTodayStats() {
    int totalSec = 0;
    final placeCounts = <String, int>{};

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final visits = {for (final v in _todayVisits) v.id: v};
    final active = _trackingEngine.activeVisit;
    if (active != null) visits[active.id] = active;
    for (final v in visits.values) {
      final seconds = SessionTime.seconds(
        v.startTime,
        v.endTime,
        from: from,
        to: now,
        now: now,
      );
      totalSec += seconds;
      if (seconds > 0) {
        placeCounts[v.placeName] = (placeCounts[v.placeName] ?? 0) + seconds;
      }
    }

    _totalTrackedToday = Duration(seconds: totalSec);

    // Calculate today's trip stats
    double distSum = 0.0;
    int tripSec = 0;
    final trips = {for (final t in _todayTrips) t.id: t};
    final activeTrip = _trackingEngine.activeTrip;
    if (activeTrip != null) {
      trips[activeTrip.id] = activeTrip.copyWith(
        distanceMeters: _trackingEngine.activeTripDistance,
      );
    }
    for (final t in trips.values) {
      distSum += SessionTime.distance(
        t.distanceMeters,
        t.startTime,
        t.endTime,
        from: from,
        to: now,
        now: now,
      );
      tripSec += SessionTime.seconds(
        t.startTime,
        t.endTime,
        from: from,
        to: now,
        now: now,
      );
    }

    _totalDistanceToday = distSum;
    _totalTripDurationToday = Duration(seconds: tripSec);

    if (placeCounts.isNotEmpty) {
      final sorted = placeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _topPlaceToday = sorted.first.key;
    } else {
      _topPlaceToday = null;
    }
  }

  String get formattedTotalToday {
    final hours = _totalTrackedToday.inHours;
    final mins = _totalTrackedToday.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String get formattedTotalDistanceToday {
    if (_totalDistanceToday >= 1000) {
      return '${(_totalDistanceToday / 1000.0).toStringAsFixed(1)} km';
    }
    return '${_totalDistanceToday.toStringAsFixed(0)} m';
  }

  String get formattedTotalTripDurationToday {
    final hours = _totalTripDurationToday.inHours;
    final mins = _totalTripDurationToday.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  Future<void> refresh() async {
    await loadData();
    await _trackingEngine.checkCurrentLocation();
  }

  @override
  void dispose() {
    _disposed = true;
    _trackingEngine.removeListener(_onTrackingEngineUpdated);
    super.dispose();
  }
}
