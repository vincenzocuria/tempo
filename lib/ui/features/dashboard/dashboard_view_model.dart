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
  })  : _visitRepository = visitRepository,
        _tripRepository = tripRepository ?? TripRepository(),
        _trackingEngine = trackingEngine {
    _trackingEngine.addListener(_onTrackingEngineUpdated);
    loadData();
  }

  String? _lastPlaceId;
  String? _lastVisitId;
  String? _lastTripId;

  void _onTrackingEngineUpdated() async {
    final currentPlaceId = _trackingEngine.currentPlace?.id;
    final currentVisitId = _trackingEngine.activeVisit?.id;
    final currentTripId = _trackingEngine.activeTrip?.id;

    if (currentPlaceId != _lastPlaceId ||
        currentVisitId != _lastVisitId ||
        currentTripId != _lastTripId) {
      _lastPlaceId = currentPlaceId;
      _lastVisitId = currentVisitId;
      _lastTripId = currentTripId;
      _todayVisits = await _visitRepository.getTodayVisits();
      _todayTrips = await _tripRepository.getTodayTrips();
    }
    _calculateTodayStats();
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _todayVisits = await _visitRepository.getTodayVisits();
      _todayTrips = await _tripRepository.getTodayTrips();
      _calculateTodayStats();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateTodayStats() {
    int totalSec = 0;
    final placeCounts = <String, int>{};

    for (final v in _todayVisits) {
      final dur = v.currentDuration;
      totalSec += dur.inSeconds;
      placeCounts[v.placeName] = (placeCounts[v.placeName] ?? 0) + dur.inSeconds;
    }

    // Add active visit if running
    final active = _trackingEngine.activeVisit;
    if (active != null) {
      final activeDur = active.currentDuration;
      if (!_todayVisits.any((v) => v.id == active.id)) {
        totalSec += activeDur.inSeconds;
        placeCounts[active.placeName] =
            (placeCounts[active.placeName] ?? 0) + activeDur.inSeconds;
      }
    }

    _totalTrackedToday = Duration(seconds: totalSec);

    // Calculate today's trip stats
    double distSum = 0.0;
    int tripSec = 0;
    for (final t in _todayTrips) {
      distSum += t.distanceMeters;
      tripSec += t.durationSeconds;
    }

    // Add active trip if running
    final activeTrip = _trackingEngine.activeTrip;
    if (activeTrip != null) {
      distSum += _trackingEngine.activeTripDistance;
      tripSec += activeTrip.currentDuration.inSeconds;
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
    _trackingEngine.removeListener(_onTrackingEngineUpdated);
    super.dispose();
  }
}
