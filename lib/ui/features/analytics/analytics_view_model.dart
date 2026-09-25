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

      _durationByPlace = await _visitRepository.getTotalDurationByPlace(from: from, to: to);
      _durationByCategory = await _visitRepository.getTotalDurationByCategory(from: from, to: to);
      _dailyDurations = await _visitRepository.getDailyDurationsForLastDays(7);

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

  int get workSeconds => _durationByCategory[PlaceCategory.lavoro] ?? 0;
  int get gymSeconds => _durationByCategory[PlaceCategory.palestra] ?? 0;
}
