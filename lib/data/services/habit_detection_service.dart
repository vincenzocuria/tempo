import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/habit_suggestion.dart';
import '../models/place_category.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

class HabitDetectionService extends ChangeNotifier {
  static final HabitDetectionService instance = HabitDetectionService._init();
  final DatabaseService _dbService;
  final LocationService _locationService;
  final NotificationService _notificationService;

  static const int minVisitsForHabit = 3;
  static const int minTotalMinutesForHabit = 45;
  static const int minDwellMinutesForVisit = 15;
  static const double clusterDistanceMeters = 110.0;
  static const int minMinutesBetweenVisits = 45;

  double? _stayLat;
  double? _stayLng;
  DateTime? _stayStartTime;
  DateTime? _lastSampleTime;
  bool _currentStayRecorded = false;

  List<HabitSuggestion> _pendingSuggestions = [];
  List<HabitSuggestion> get pendingSuggestions => _pendingSuggestions;

  HabitDetectionService._init({
    DatabaseService? dbService,
    LocationService? locationService,
    NotificationService? notificationService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _locationService = locationService ?? LocationService.instance,
        _notificationService = notificationService ?? NotificationService.instance;

  Future<void> initialize() async {
    // Pulisce vecchi suggerimenti da singole soste occasionali (< 3 visite)
    await _dbService.demoteNonHabitSuggestions();
    await refreshPendingSuggestions();
  }

  Future<void> refreshPendingSuggestions() async {
    _pendingSuggestions = await _dbService.getPendingHabitSuggestions();
    notifyListeners();
  }

  /// Called by TrackingEngine whenever user is OUTSIDE any known registered place
  Future<void> processUnregisteredLocation(double lat, double lng) async {
    final now = DateTime.now();

    if (_stayLat == null || _stayLng == null) {
      _stayLat = lat;
      _stayLng = lng;
      _stayStartTime = now;
      _lastSampleTime = now;
      _currentStayRecorded = false;
      return;
    }

    final distance = _locationService.calculateDistance(
      _stayLat!,
      _stayLng!,
      lat,
      lng,
    );

    // If within 90 meters, user is lingering at this location
    if (distance <= 90.0) {
      _lastSampleTime = now;
      final dwellMinutes = now.difference(_stayStartTime!).inMinutes;

      // Checkpoint the stay once it reaches the minimum threshold of 15 min
      if (dwellMinutes >= minDwellMinutesForVisit && !_currentStayRecorded) {
        _currentStayRecorded = true;
        await _recordOrUpdateCandidate(
          lat: _stayLat!,
          lng: _stayLng!,
          minutes: dwellMinutes,
          isNewVisitSession: true,
        );
      }
    } else {
      // User moved away: finalize previous stay if it was significant (>= 15 minutes)
      if (_stayStartTime != null && _lastSampleTime != null) {
        final totalDwell = _lastSampleTime!.difference(_stayStartTime!).inMinutes;
        if (totalDwell >= minDwellMinutesForVisit && !_currentStayRecorded) {
          await _recordOrUpdateCandidate(
            lat: _stayLat!,
            lng: _stayLng!,
            minutes: totalDwell,
            isNewVisitSession: true,
          );
        }
      }

      // Reset to new location
      _stayLat = lat;
      _stayLng = lng;
      _stayStartTime = now;
      _lastSampleTime = now;
      _currentStayRecorded = false;
    }
  }

  /// User entered a registered place: finalize any pending unregistered dwell
  Future<void> onEnteredKnownPlace() async {
    if (_stayStartTime != null && _lastSampleTime != null && _stayLat != null) {
      final totalDwell = _lastSampleTime!.difference(_stayStartTime!).inMinutes;
      if (totalDwell >= minDwellMinutesForVisit && !_currentStayRecorded) {
        await _recordOrUpdateCandidate(
          lat: _stayLat!,
          lng: _stayLng!,
          minutes: totalDwell,
          isNewVisitSession: true,
        );
      }
    }
    _stayLat = null;
    _stayLng = null;
    _stayStartTime = null;
    _lastSampleTime = null;
    _currentStayRecorded = false;
  }

  Future<void> _recordOrUpdateCandidate({
    required double lat,
    required double lng,
    required int minutes,
    required bool isNewVisitSession,
  }) async {
    final existing = await _dbService.findNearbyHabitSuggestion(lat, lng, maxDistanceMeters: clusterDistanceMeters);
    final now = DateTime.now();

    if (existing != null) {
      // Non riproporre se già archiviato o salvato
      if (existing.status == HabitStatus.dismissed || existing.status == HabitStatus.saved) {
        return;
      }

      // Calcola se si tratta di una visita distinta e separata nel tempo
      final minutesSinceLast = now.difference(existing.lastDetected).inMinutes;
      final isDistinctVisit = isNewVisitSession &&
          (minutesSinceLast >= minMinutesBetweenVisits || now.day != existing.lastDetected.day);

      final updatedVisits = isDistinctVisit ? existing.visitCount + 1 : existing.visitCount;
      final updatedMinutes = existing.totalMinutesSpent + minutes;

      // CRITERI DI VERA ABITUDINE:
      // 1. Almeno 3 visite distinte
      // 2. Almeno 45 minuti totali accumulati
      // 3. Distribuzione su giorni diversi o ad almeno 20 ore di distanza (non una sosta singola continuata)
      final hoursSpan = now.difference(existing.firstDetected).inHours;
      final qualifiesAsHabit = updatedVisits >= minVisitsForHabit &&
          updatedMinutes >= minTotalMinutesForHabit &&
          (hoursSpan >= 20 || updatedVisits >= 4);

      final newStatus = qualifiesAsHabit ? HabitStatus.pending : HabitStatus.learning;

      final updated = existing.copyWith(
        lastDetected: now,
        totalMinutesSpent: updatedMinutes,
        visitCount: updatedVisits,
        status: newStatus,
      );
      await _dbService.updateHabitSuggestion(updated);

      // NOTIFICA ESCLUSIVAMENTE quando viene raggiunta la qualifica di abitudine
      if (qualifiesAsHabit && existing.status == HabitStatus.learning) {
        await _notificationService.showLocalNotification(
          title: '📍 Luogo abituale rilevato',
          body: 'Sei stato qui $updatedVisits volte in giorni diversi (${updated.formattedDuration} totali). Vuoi salvarlo tra i tuoi luoghi?',
        );
      }
    } else {
      // Prima visita: crea candidato in modalità silenziosa LEARNING (nessuna notifica, nessuna proposta)
      final category = _inferCategoryByTime(now);
      final newCandidate = HabitSuggestion(
        latitude: lat,
        longitude: lng,
        firstDetected: _stayStartTime ?? now,
        lastDetected: now,
        visitCount: 1,
        totalMinutesSpent: minutes,
        suggestedName: _inferName(category),
        suggestedCategory: category,
        status: HabitStatus.learning,
      );
      await _dbService.insertHabitSuggestion(newCandidate);
    }

    await refreshPendingSuggestions();
  }

  PlaceCategory _inferCategoryByTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 21 || hour < 7) {
      return PlaceCategory.secondaCasa;
    } else if (hour >= 8 && hour <= 18) {
      return PlaceCategory.lavoro;
    } else {
      return PlaceCategory.svago;
    }
  }

  String _inferName(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.secondaCasa:
        return 'Nuova Casa / Sosta serale';
      case PlaceCategory.lavoro:
      case PlaceCategory.secondoLavoro:
        return 'Nuovo Ufficio / Postazione';
      case PlaceCategory.svago:
        return 'Punto di ritrovo / Svago';
      default:
        return 'Luogo Frequente Rilevato';
    }
  }

  /// Direct manual simulation for testing/demo purposes
  Future<void> simulateHabitStay({
    double? lat,
    double? lng,
    int minutes = 90,
    int visits = 3,
  }) async {
    final simLat = lat ?? 45.4680;
    final simLng = lng ?? 9.1850;

    final candidate = HabitSuggestion(
      latitude: simLat,
      longitude: simLng,
      firstDetected: DateTime.now().subtract(const Duration(days: 3)),
      lastDetected: DateTime.now(),
      visitCount: visits,
      totalMinutesSpent: minutes,
      suggestedName: 'Nuova Seconda Casa Rilevata',
      suggestedCategory: PlaceCategory.secondaCasa,
      status: HabitStatus.pending,
    );

    await _dbService.insertHabitSuggestion(candidate);
    await refreshPendingSuggestions();

    await _notificationService.showLocalNotification(
      title: '📍 Luogo abituale rilevato!',
      body: 'Sei stato qui $visits volte in giorni diversi (${candidate.formattedDuration} totali). Vuoi salvarlo tra i tuoi luoghi?',
    );
  }

  Future<void> dismissSuggestion(String id) async {
    await _dbService.dismissHabitSuggestion(id);
    await refreshPendingSuggestions();
  }

  Future<void> markSaved(String id) async {
    await _dbService.markHabitSuggestionSaved(id);
    await refreshPendingSuggestions();
  }
}
