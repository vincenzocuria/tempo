import 'package:flutter/material.dart';
import '../../../data/models/place_category.dart';
import '../../../data/repositories/visit_repository.dart';

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

  AnalyticsViewModel({required VisitRepository visitRepository})
      : _visitRepository = visitRepository {
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

      // Filter out zero-duration places and categories so only actual data is shown
      _durationByPlace = Map.fromEntries(
        rawPlaces.entries.where((e) => e.value > 0),
      );
      _durationByCategory = Map.fromEntries(
        rawCategories.entries.where((e) => e.value > 0),
      );

      _totalDurationSeconds = _durationByPlace.values.fold(0, (sum, val) => sum + val);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String formatSeconds(int totalSec) {
    final hours = totalSec ~/ 3600;
    final mins = (totalSec % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
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
