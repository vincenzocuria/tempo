import 'package:flutter/material.dart';
import '../../../data/models/place_category.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/tracking_engine.dart';

enum AnalyticsTimeFilter {
  today,
  thisWeek,
  thisMonth,
  allTime;

  String get displayName {
    switch (this) {
      case AnalyticsTimeFilter.today:
        return 'Oggi';
      case AnalyticsTimeFilter.thisWeek:
        return 'Settimana';
      case AnalyticsTimeFilter.thisMonth:
        return 'Mese';
      case AnalyticsTimeFilter.allTime:
        return 'Tutto';
    }
  }
}

class AnalyticsViewModel extends ChangeNotifier {
  final VisitRepository _visitRepository;
  final TripRepository? _tripRepository;
  final TrackingEngine? _trackingEngine;

  AnalyticsTimeFilter _selectedFilter = AnalyticsTimeFilter.thisWeek;
  AnalyticsTimeFilter get selectedFilter => _selectedFilter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, int> _durationByPlace = {};
  Map<String, int> get durationByPlace => _durationByPlace;

  Map<PlaceCategory, int> _durationByCategory = {};
  Map<PlaceCategory, int> get durationByCategory => _durationByCategory;

  Map<String, int> _dailyDurations = {};
  Map<String, int> get dailyDurations => _dailyDurations;

  int _totalDurationSeconds = 0;
  int get totalDurationSeconds => _totalDurationSeconds;

  int _totalTripsCount = 0;
  int get totalTripsCount => _totalTripsCount;

  int _totalTripDurationSeconds = 0;
  int get totalTripDurationSeconds => _totalTripDurationSeconds;

  double _totalTripDistanceMeters = 0.0;
  double get totalTripDistanceMeters => _totalTripDistanceMeters;

  AnalyticsViewModel({
    required VisitRepository visitRepository,
    TripRepository? tripRepository,
    TrackingEngine? trackingEngine,
  })  : _visitRepository = visitRepository,
        _tripRepository = tripRepository,
        _trackingEngine = trackingEngine {
    loadAnalytics();
  }

  void setFilter(AnalyticsTimeFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      DateTime? from;
      DateTime? to = now;

      switch (_selectedFilter) {
        case AnalyticsTimeFilter.today:
          from = DateTime(now.year, now.month, now.day);
          break;
        case AnalyticsTimeFilter.thisWeek:
          from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          break;
        case AnalyticsTimeFilter.thisMonth:
          from = DateTime(now.year, now.month, 1);
          break;
        case AnalyticsTimeFilter.allTime:
          from = null;
          to = null;
          break;
      }

      final rawPlaces = await _visitRepository.getTotalDurationByPlace(from: from, to: to);
      final rawCategories = await _visitRepository.getTotalDurationByCategory(from: from, to: to);
      _dailyDurations = await _visitRepository.getDailyDurationsForLastDays(7);

      final placesMap = Map<String, int>.from(rawPlaces);
      final categoriesMap = Map<PlaceCategory, int>.from(rawCategories);

      // Include active ongoing visit if within time window
      final engine = _trackingEngine;
      if (engine != null) {
        final activeVisit = engine.activeVisit;
        final currentPlace = engine.currentPlace;
        if (activeVisit != null && currentPlace != null) {
          final isInsideWindow = from == null || activeVisit.startTime.isAfter(from);
          if (isInsideWindow) {
            final activeSec = activeVisit.currentDuration.inSeconds;
            if (activeSec > 0) {
              placesMap[currentPlace.name] = (placesMap[currentPlace.name] ?? 0) + activeSec;
              categoriesMap[currentPlace.category] = (categoriesMap[currentPlace.category] ?? 0) + activeSec;

              final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
              _dailyDurations[todayKey] = (_dailyDurations[todayKey] ?? 0) + activeSec;
            }
          }
        }
      }

      // Filter out zero-duration places and categories so only actual data is shown
      _durationByPlace = Map.fromEntries(
        placesMap.entries.where((e) => e.value > 0),
      );
      _durationByCategory = Map.fromEntries(
        categoriesMap.entries.where((e) => e.value > 0),
      );

      _totalDurationSeconds = _durationByPlace.values.fold(0, (sum, val) => sum + val);

      // Load trips data if repository available
      final tripRepo = _tripRepository;
      if (tripRepo != null) {
        final trips = await tripRepo.getTrips(from: from, to: to);
        _totalTripsCount = trips.length;
        _totalTripDurationSeconds = await tripRepo.getTotalTripDuration(from: from, to: to);
        _totalTripDistanceMeters = await tripRepo.getTotalDistance(from: from, to: to);
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String formatSeconds(int totalSec) {
    if (totalSec <= 0) return '0m';
    final hours = totalSec ~/ 3600;
    final mins = (totalSec % 3600) ~/ 60;
    if (hours > 0) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${mins}m';
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  List<MapEntry<String, int>> get sortedPlaces {
    final list = _durationByPlace.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  MapEntry<String, int>? get topPlace {
    final list = sortedPlaces;
    return list.isNotEmpty ? list.first : null;
  }

  MapEntry<String, int>? get secondTopPlace {
    final list = sortedPlaces;
    return list.length > 1 ? list[1] : null;
  }

  int get placesVisitedCount => _durationByPlace.keys.length;
}
