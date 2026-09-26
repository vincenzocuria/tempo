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

  double? _stayLat;
  double? _stayLng;
  DateTime? _stayStartTime;
  DateTime? _lastSampleTime;

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

      // When user stays > 15 minutes at this unregistered spot, register or update habit candidate
      if (dwellMinutes >= 15) {
        await _recordOrUpdateCandidate(
          lat: _stayLat!,
          lng: _stayLng!,
          minutes: dwellMinutes,
          isLiveSession: true,
        );
      }
    } else {
      // User moved away: finalize previous stay if it was significant (>= 10 minutes)
      if (_stayStartTime != null && _lastSampleTime != null) {
        final totalDwell = _lastSampleTime!.difference(_stayStartTime!).inMinutes;
        if (totalDwell >= 10) {
          await _recordOrUpdateCandidate(
            lat: _stayLat!,
            lng: _stayLng!,
            minutes: totalDwell,
            isLiveSession: false,
          );
        }
      }

      // Reset to new location
      _stayLat = lat;
      _stayLng = lng;
      _stayStartTime = now;
      _lastSampleTime = now;
    }
  }

  /// User entered a registered place: finalize any pending unregistered dwell
  Future<void> onEnteredKnownPlace() async {
    if (_stayStartTime != null && _lastSampleTime != null && _stayLat != null) {
      final totalDwell = _lastSampleTime!.difference(_stayStartTime!).inMinutes;
      if (totalDwell >= 10) {
        await _recordOrUpdateCandidate(
          lat: _stayLat!,
          lng: _stayLng!,
          minutes: totalDwell,
          isLiveSession: false,
        );
      }
    }
    _stayLat = null;
    _stayLng = null;
    _stayStartTime = null;
    _lastSampleTime = null;
  }

  Future<void> _recordOrUpdateCandidate({
    required double lat,
    required double lng,
    required int minutes,
    required bool isLiveSession,
  }) async {
    final existing = await _dbService.findNearbyHabitSuggestion(lat, lng, maxDistanceMeters: 130.0);

    if (existing != null) {
      // Update existing habit suggestion
      final updated = existing.copyWith(
        lastDetected: DateTime.now(),
        totalMinutesSpent: isLiveSession ? (existing.totalMinutesSpent + 5) : (existing.totalMinutesSpent + minutes),
        visitCount: isLiveSession ? existing.visitCount : (existing.visitCount + 1),
      );
      await _dbService.updateHabitSuggestion(updated);
    } else {
      // Create new habit candidate
      final now = DateTime.now();
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
        status: HabitStatus.pending,
      );
      await _dbService.insertHabitSuggestion(newCandidate);

      // Trigger notification
      await _notificationService.showLocalNotification(
        title: '📍 Luogo abituale rilevato',
        body: 'Hai trascorso $minutes min in questa zona. Vuoi salvarla tra i tuoi luoghi?',
      );
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
    int minutes = 45,
    int visits = 3,
  }) async {
    final simLat = lat ?? 45.4680;
    final simLng = lng ?? 9.1850;

    final candidate = HabitSuggestion(
      latitude: simLat,
      longitude: simLng,
      visitCount: visits,
      totalMinutesSpent: minutes,
      suggestedName: 'Luogo abituale rilevato',
      suggestedCategory: PlaceCategory.secondaCasa,
      status: HabitStatus.pending,
    );

    await _dbService.insertHabitSuggestion(candidate);
    await refreshPendingSuggestions();

    await _notificationService.showLocalNotification(
      title: '📍 Luogo frequente rilevato!',
      body: 'Hai trascorso ${candidate.formattedDuration} ($visits visite) qui. Vuoi salvarlo?',
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
