import 'package:flutter/material.dart';
import '../../../data/models/visit_session.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/tracking_engine.dart';

class DashboardViewModel extends ChangeNotifier {
  final VisitRepository _visitRepository;
  final TrackingEngine _trackingEngine;

  List<VisitSession> _todayVisits = [];
  List<VisitSession> get todayVisits => _todayVisits;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Duration _totalTrackedToday = Duration.zero;
  Duration get totalTrackedToday => _totalTrackedToday;

  String? _topPlaceToday;
  String? get topPlaceToday => _topPlaceToday;

  DashboardViewModel({
    required VisitRepository visitRepository,
    required TrackingEngine trackingEngine,
  })  : _visitRepository = visitRepository,
        _trackingEngine = trackingEngine {
    _trackingEngine.addListener(_onTrackingEngineUpdated);
    loadData();
  }

  void _onTrackingEngineUpdated() {
    _calculateTodayStats();
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _todayVisits = await _visitRepository.getTodayVisits();
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
      // If not already in _todayVisits
      if (!_todayVisits.any((v) => v.id == active.id)) {
        totalSec += activeDur.inSeconds;
        placeCounts[active.placeName] = (placeCounts[active.placeName] ?? 0) + activeDur.inSeconds;
      }
    }

    _totalTrackedToday = Duration(seconds: totalSec);

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
