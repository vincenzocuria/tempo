import '../../../data/services/session_time.dart';

import 'package:flutter/material.dart';

import '../../../data/models/place_category.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/visit_session.dart';
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

class TransportModeStats {
  final String modeName;
  final String modeKey; // 'car', 'walk', 'bike', 'other'
  final IconData icon;
  final Color color;
  final int durationSeconds;
  final double distanceMeters;
  final int tripCount;

  const TransportModeStats({
    required this.modeName,
    required this.modeKey,
    required this.icon,
    required this.color,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.tripCount,
  });

  String get formattedDuration {
    if (durationSeconds <= 0) return '0m';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    return '${m}m';
  }

  String get formattedDistance {
    if (distanceMeters < 1000) return '${distanceMeters.toInt()} m';
    final km = distanceMeters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  double get avgSpeedKmh {
    if (durationSeconds <= 10) return 0.0;
    return (distanceMeters / 1000.0) / (durationSeconds / 3600.0);
  }
}

class CategoryTimeStats {
  final PlaceCategory category;
  final int durationSeconds;
  final int visitCount;
  final int distinctDaysCount;
  final double percentageOfTotal;

  const CategoryTimeStats({
    required this.category,
    required this.durationSeconds,
    required this.visitCount,
    required this.distinctDaysCount,
    required this.percentageOfTotal,
  });

  String get formattedDuration {
    if (durationSeconds <= 0) return '0m';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    return '${m}m';
  }

  String get dailyAverageFormatted {
    if (distinctDaysCount <= 0 || durationSeconds <= 0) {
      return formattedDuration;
    }
    final avgSec = durationSeconds ~/ distinctDaysCount;
    final h = avgSec ~/ 3600;
    final m = (avgSec % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '${h}h ${m}m / g' : '${h}h / g';
    return '${m}m / g';
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

  // Rich direct answers breakdown
  TransportModeStats _carStats = const TransportModeStats(
    modeName: 'In auto',
    modeKey: 'car',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7),
    durationSeconds: 0,
    distanceMeters: 0,
    tripCount: 0,
  );
  TransportModeStats get carStats => _carStats;

  TransportModeStats _motoStats = const TransportModeStats(
    modeName: 'In moto / scooter',
    modeKey: 'moto',
    icon: Icons.two_wheeler_rounded,
    color: Color(0xFFF97316),
    durationSeconds: 0,
    distanceMeters: 0,
    tripCount: 0,
  );
  TransportModeStats get motoStats => _motoStats;

  TransportModeStats _walkStats = const TransportModeStats(
    modeName: 'A piedi',
    modeKey: 'walk',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF10B981),
    durationSeconds: 0,
    distanceMeters: 0,
    tripCount: 0,
  );
  TransportModeStats get walkStats => _walkStats;

  TransportModeStats _runStats = const TransportModeStats(
    modeName: 'Corsa',
    modeKey: 'run',
    icon: Icons.directions_run_rounded,
    color: Color(0xFFEC4899),
    durationSeconds: 0,
    distanceMeters: 0,
    tripCount: 0,
  );
  TransportModeStats get runStats => _runStats;

  TransportModeStats _bikeStats = const TransportModeStats(
    modeName: 'In bicicletta',
    modeKey: 'bike',
    icon: Icons.directions_bike_rounded,
    color: Color(0xFF14B8A6),
    durationSeconds: 0,
    distanceMeters: 0,
    tripCount: 0,
  );
  TransportModeStats get bikeStats => _bikeStats;

  List<TransportModeStats> _allTransportStats = [];
  List<TransportModeStats> get allTransportStats => _allTransportStats;

  List<CategoryTimeStats> _categoryStatsList = [];
  final Map<PlaceCategory, Set<String>> _categoryDays = {};
  List<CategoryTimeStats> get categoryStatsList => _categoryStatsList;

  List<Trip> _recentFilteredTrips = [];
  List<Trip> get recentFilteredTrips => _recentFilteredTrips;

  List<VisitSession> _recentFilteredVisits = [];
  List<VisitSession> get recentFilteredVisits => _recentFilteredVisits;

  int _lastPlacesVersion = 0;
  bool _disposed = false;
  bool _reloadPending = false;
  String? _lastActiveVisitId;
  String? _lastActiveTripId;
  int _lastRefreshMinute = -1;

  AnalyticsViewModel({
    required VisitRepository visitRepository,
    TripRepository? tripRepository,
    TrackingEngine? trackingEngine,
  }) : _visitRepository = visitRepository,
       _tripRepository = tripRepository,
       _trackingEngine = trackingEngine {
    _trackingEngine?.addListener(_onTrackingEngineUpdated);
    loadAnalytics();
  }

  void _onTrackingEngineUpdated() {
    final currentPlacesVersion = _trackingEngine?.placesVersion ?? 0;
    final visitId = _trackingEngine?.activeVisit?.id;
    final tripId = _trackingEngine?.activeTrip?.id;
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    if (currentPlacesVersion != _lastPlacesVersion ||
        visitId != _lastActiveVisitId ||
        tripId != _lastActiveTripId ||
        minute != _lastRefreshMinute) {
      _lastActiveVisitId = visitId;
      _lastActiveTripId = tripId;
      _lastRefreshMinute = minute;
      _lastPlacesVersion = currentPlacesVersion;
      loadAnalytics();
    }
  }

  void setFilter(AnalyticsTimeFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    loadAnalytics();
  }

  String get filterDateRangeLabel {
    final now = DateTime.now();
    const months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];
    switch (_selectedFilter) {
      case AnalyticsTimeFilter.today:
        return 'Oggi, ${now.day} ${months[now.month - 1]} ${now.year}';
      case AnalyticsTimeFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]} (Settimana corrente)';
      case AnalyticsTimeFilter.thisMonth:
        return '${months[now.month - 1]} ${now.year} (Mese corrente)';
      case AnalyticsTimeFilter.allTime:
        return 'Dall\'inizio del tracciamento';
    }
  }

  CategoryTimeStats? _combinedCategoryStats(
    bool Function(PlaceCategory) matches,
  ) {
    final stats = _categoryStatsList.where((s) => matches(s.category)).toList();
    if (stats.isEmpty) return null;
    final days = <String>{};
    for (final stat in stats) {
      days.addAll(_categoryDays[stat.category] ?? {});
    }
    final seconds = stats.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    return CategoryTimeStats(
      category: stats.first.category,
      durationSeconds: seconds,
      visitCount: stats.fold<int>(0, (sum, s) => sum + s.visitCount),
      distinctDaysCount: days.length,
      percentageOfTotal: _totalDurationSeconds > 0
          ? seconds / _totalDurationSeconds
          : 0,
    );
  }

  CategoryTimeStats? get workStats => _combinedCategoryStats((cat) {
    final name = cat.displayName.toLowerCase();
    return cat == PlaceCategory.lavoro ||
        cat == PlaceCategory.secondoLavoro ||
        name.contains('lavoro') ||
        name.contains('ufficio');
  });
  CategoryTimeStats? get homeStats => _combinedCategoryStats(
    (cat) =>
        cat == PlaceCategory.casa ||
        cat == PlaceCategory.secondaCasa ||
        cat.displayName.toLowerCase().contains('casa'),
  );
  CategoryTimeStats? get fitnessStats => _combinedCategoryStats((cat) {
    final name = cat.displayName.toLowerCase();
    return cat == PlaceCategory.palestra ||
        name.contains('palestra') ||
        name.contains('sport') ||
        name.contains('fitness');
  });

  Future<void> loadAnalytics() async {
    if (_disposed) return;
    if (_isLoading) {
      _reloadPending = true;
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      DateTime? from;
      DateTime? to;

      switch (_selectedFilter) {
        case AnalyticsTimeFilter.today:
          from = DateTime(now.year, now.month, now.day, 0, 0, 0);
          to = DateTime(now.year, now.month, now.day + 1);
          break;
        case AnalyticsTimeFilter.thisWeek:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          from = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
          final sunday = monday.add(const Duration(days: 6));
          to = DateTime(sunday.year, sunday.month, sunday.day + 1);
          break;
        case AnalyticsTimeFilter.thisMonth:
          from = DateTime(now.year, now.month, 1, 0, 0, 0);
          final nextMonth = now.month < 12
              ? DateTime(now.year, now.month + 1, 1)
              : DateTime(now.year + 1, 1, 1);
          to = nextMonth;
          break;
        case AnalyticsTimeFilter.allTime:
          from = null;
          to = null;
          break;
      }

      final engine = _trackingEngine;
      final storedVisits = await _visitRepository.getVisits(from: from, to: to);
      if (_disposed) return;
      final byId = {for (final v in storedVisits) v.id: v};
      final active = engine?.activeVisit;
      if (active != null) byId[active.id] = active;
      final allFilteredVisits = byId.values
          .where(
            (v) =>
                SessionTime.seconds(
                  v.startTime,
                  v.endTime,
                  from: from,
                  to: to,
                  now: now,
                ) >
                0,
          )
          .toList();
      _recentFilteredVisits = allFilteredVisits;
      final placesMap = <String, int>{};
      final categoriesMap = <PlaceCategory, int>{};
      for (final v in allFilteredVisits) {
        final seconds = SessionTime.seconds(
          v.startTime,
          v.endTime,
          from: from,
          to: to,
          now: now,
        );
        placesMap[v.placeName] = (placesMap[v.placeName] ?? 0) + seconds;
        categoriesMap[v.category] = (categoriesMap[v.category] ?? 0) + seconds;
      }
      _dailyDurations = await _visitRepository.getDailyDurationsForLastDays(7);
      if (_disposed) return;

      // Filter out zero-duration places and categories so only actual data is shown
      _durationByPlace = Map.fromEntries(
        placesMap.entries.where((e) => e.value > 0),
      );
      _durationByCategory = Map.fromEntries(
        categoriesMap.entries.where((e) => e.value > 0),
      );

      _totalDurationSeconds = _durationByPlace.values.fold(
        0,
        (sum, val) => sum + val,
      );

      // Build granular category stats (with visit counts and distinct days)
      final Map<PlaceCategory, List<VisitSession>> visitsByCat = {};
      for (final v in allFilteredVisits) {
        visitsByCat.putIfAbsent(v.category, () => []).add(v);
      }
      final catStats = <CategoryTimeStats>[];
      _categoryDays.clear();
      for (final entry in visitsByCat.entries) {
        final cat = entry.key;
        final list = entry.value;

        int durSec = 0;
        final distinctDays = <String>{};

        for (final v in list) {
          durSec += SessionTime.seconds(
            v.startTime,
            v.endTime,
            from: from,
            to: to,
            now: now,
          );
          distinctDays.addAll(
            SessionTime.daily(
              v.startTime,
              v.endTime,
              from: from,
              to: to,
              now: now,
            ).keys,
          );
        }

        _categoryDays[cat] = distinctDays;
        final pct = _totalDurationSeconds > 0
            ? (durSec / _totalDurationSeconds)
            : 0.0;
        catStats.add(
          CategoryTimeStats(
            category: cat,
            durationSeconds: durSec,
            visitCount: list.length,
            distinctDaysCount: distinctDays.length,
            percentageOfTotal: pct,
          ),
        );
      }
      catStats.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
      _categoryStatsList = catStats;

      // Load trips data & group by transport mode
      final tripRepo = _tripRepository;
      if (tripRepo != null) {
        final storedTrips = await tripRepo.getTrips(from: from, to: to);
        if (_disposed) return;
        final tripsById = {for (final t in storedTrips) t.id: t};
        final activeTrip = engine?.activeTrip;
        if (activeTrip != null) {
          tripsById[activeTrip.id] = activeTrip.copyWith(
            distanceMeters: engine!.activeTripDistance,
          );
        }
        final trips = tripsById.values
            .where(
              (t) =>
                  SessionTime.seconds(
                    t.startTime,
                    t.endTime,
                    from: from,
                    to: to,
                    now: now,
                  ) >
                  0,
            )
            .map(
              (t) => t.copyWith(
                durationSeconds: SessionTime.seconds(
                  t.startTime,
                  t.endTime,
                  from: from,
                  to: to,
                  now: now,
                ),
                distanceMeters: SessionTime.distance(
                  t.distanceMeters,
                  t.startTime,
                  t.endTime,
                  from: from,
                  to: to,
                  now: now,
                ),
              ),
            )
            .toList();
        _recentFilteredTrips = trips;
        _totalTripsCount = trips.length;
        _totalTripDurationSeconds = trips.fold(
          0,
          (sum, t) => sum + t.durationSeconds,
        );
        _totalTripDistanceMeters = trips.fold(
          0.0,
          (sum, t) => sum + t.distanceMeters,
        );

        int carSec = 0;
        double carDist = 0.0;
        int carTrips = 0;

        int motoSec = 0;
        double motoDist = 0.0;
        int motoTrips = 0;

        int walkSec = 0;
        double walkDist = 0.0;
        int walkTrips = 0;

        int runSec = 0;
        double runDist = 0.0;
        int runTrips = 0;

        int bikeSec = 0;
        double bikeDist = 0.0;
        int bikeTrips = 0;

        int otherSec = 0;
        double otherDist = 0.0;
        int otherTrips = 0;

        for (final t in trips) {
          final mode = t.transportMode.toLowerCase();
          if (mode.contains('moto') || mode.contains('scooter')) {
            motoSec += t.durationSeconds;
            motoDist += t.distanceMeters;
            motoTrips++;
          } else if (mode.contains('auto') ||
              mode.contains('macchina') ||
              mode.contains('veicolo')) {
            carSec += t.durationSeconds;
            carDist += t.distanceMeters;
            carTrips++;
          } else if (mode.contains('bici') ||
              mode.contains('bicicletta') ||
              mode.contains('cycling')) {
            bikeSec += t.durationSeconds;
            bikeDist += t.distanceMeters;
            bikeTrips++;
          } else if (mode.contains('corsa') || mode.contains('running')) {
            runSec += t.durationSeconds;
            runDist += t.distanceMeters;
            runTrips++;
          } else if (mode.contains('piedi') ||
              mode.contains('cammin') ||
              mode.contains('walk')) {
            walkSec += t.durationSeconds;
            walkDist += t.distanceMeters;
            walkTrips++;
          } else if (mode.contains('mezzo')) {
            if (engine?.preferredMotorVehicle == TransportMode.moto) {
              motoSec += t.durationSeconds;
              motoDist += t.distanceMeters;
              motoTrips++;
            } else {
              carSec += t.durationSeconds;
              carDist += t.distanceMeters;
              carTrips++;
            }
          } else {
            // Speed inference fallback if old trips had generic mode
            if (t.distanceMeters > 0 && t.durationSeconds > 0) {
              final avgSpd =
                  (t.distanceMeters / 1000.0) / (t.durationSeconds / 3600.0);
              if (avgSpd > 22.0) {
                if (engine?.preferredMotorVehicle == TransportMode.moto) {
                  motoSec += t.durationSeconds;
                  motoDist += t.distanceMeters;
                  motoTrips++;
                } else {
                  carSec += t.durationSeconds;
                  carDist += t.distanceMeters;
                  carTrips++;
                }
              } else if (avgSpd > 7.0) {
                bikeSec += t.durationSeconds;
                bikeDist += t.distanceMeters;
                bikeTrips++;
              } else {
                walkSec += t.durationSeconds;
                walkDist += t.distanceMeters;
                walkTrips++;
              }
            } else {
              otherSec += t.durationSeconds;
              otherDist += t.distanceMeters;
              otherTrips++;
            }
          }
        }

        _carStats = TransportModeStats(
          modeName: 'In auto',
          modeKey: 'car',
          icon: Icons.directions_car_rounded,
          color: const Color(0xFF0284C7),
          durationSeconds: carSec,
          distanceMeters: carDist,
          tripCount: carTrips,
        );

        _motoStats = TransportModeStats(
          modeName: 'In moto / scooter',
          modeKey: 'moto',
          icon: Icons.two_wheeler_rounded,
          color: const Color(0xFFF97316),
          durationSeconds: motoSec,
          distanceMeters: motoDist,
          tripCount: motoTrips,
        );

        _walkStats = TransportModeStats(
          modeName: 'A piedi',
          modeKey: 'walk',
          icon: Icons.directions_walk_rounded,
          color: const Color(0xFF10B981),
          durationSeconds: walkSec,
          distanceMeters: walkDist,
          tripCount: walkTrips,
        );

        _runStats = TransportModeStats(
          modeName: 'Corsa',
          modeKey: 'run',
          icon: Icons.directions_run_rounded,
          color: const Color(0xFFEC4899),
          durationSeconds: runSec,
          distanceMeters: runDist,
          tripCount: runTrips,
        );

        _bikeStats = TransportModeStats(
          modeName: 'In bicicletta',
          modeKey: 'bike',
          icon: Icons.directions_bike_rounded,
          color: const Color(0xFF14B8A6),
          durationSeconds: bikeSec,
          distanceMeters: bikeDist,
          tripCount: bikeTrips,
        );

        final list = <TransportModeStats>[];
        if (carTrips > 0 || carSec > 0) list.add(_carStats);
        if (motoTrips > 0 || motoSec > 0) list.add(_motoStats);
        if (bikeTrips > 0 || bikeSec > 0) list.add(_bikeStats);
        if (walkTrips > 0 || walkSec > 0) list.add(_walkStats);
        if (runTrips > 0 || runSec > 0) list.add(_runStats);
        if (otherTrips > 0 || otherSec > 0) {
          list.add(
            TransportModeStats(
              modeName: 'Altri spostamenti',
              modeKey: 'other',
              icon: Icons.route_rounded,
              color: const Color(0xFF8B5CF6),
              durationSeconds: otherSec,
              distanceMeters: otherDist,
              tripCount: otherTrips,
            ),
          );
        }
        _allTransportStats = list;
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
        if (_reloadPending) {
          _reloadPending = false;
          loadAnalytics();
        }
      }
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

  @override
  void dispose() {
    _disposed = true;
    _trackingEngine?.removeListener(_onTrackingEngineUpdated);
    super.dispose();
  }
}
