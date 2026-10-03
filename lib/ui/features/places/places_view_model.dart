import 'package:flutter/material.dart';

import '../../../data/models/place.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/tracking_engine.dart';

class PlacesViewModel extends ChangeNotifier {
  final PlaceRepository _placeRepository;
  final VisitRepository _visitRepository;
  final TrackingEngine _trackingEngine;

  List<Place> _places = [];
  List<Place> get places => _places;

  Map<String, int> _placeTotalDurations = {};
  Map<String, int> get placeTotalDurations => _placeTotalDurations;

  bool _isLoading = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  bool get isLoading => _isLoading;

  PlacesViewModel({
    required PlaceRepository placeRepository,
    required VisitRepository visitRepository,
    required TrackingEngine trackingEngine,
  }) : _placeRepository = placeRepository,
       _visitRepository = visitRepository,
       _trackingEngine = trackingEngine {
    loadPlaces();
  }

  Future<void> loadPlaces({bool forceRefresh = false}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    // Only show full loading spinner if we don't have any places in memory yet
    if (_places.isEmpty || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Fetch places first and display immediately (takes < 2ms)
      final places = await _placeRepository.getAllPlaces();
      if (_disposed || generation != _loadGeneration) return;
      _places = places;
      _isLoading = false;
      notifyListeners();

      // 2. Fetch duration aggregates in background without delaying list display
      final durations = await _visitRepository.getTotalDurationByPlace();
      if (_disposed || generation != _loadGeneration) return;
      _placeTotalDurations = durations;
      notifyListeners();
    } catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlace(Place place) async {
    // Deduplication check: ignore if an exact duplicate is already in list
    final existingIndex = _places.indexWhere(
      (p) =>
          p.id == place.id ||
          (p.name.trim().toLowerCase() == place.name.trim().toLowerCase() &&
              (p.latitude - place.latitude).abs() < 0.0001 &&
              (p.longitude - place.longitude).abs() < 0.0001),
    );

    if (existingIndex != -1) {
      return;
    }

    await _placeRepository.savePlace(place);
    ++_loadGeneration;
    if (_disposed) return;
    _places.insert(0, place);
    notifyListeners();
    await loadPlaces();
    _trackingEngine.checkCurrentLocation();
  }

  Future<void> updatePlace(Place place) async {
    await _placeRepository.updatePlace(place);
    ++_loadGeneration;
    if (_disposed) return;
    final index = _places.indexWhere((p) => p.id == place.id);
    if (index != -1) _places[index] = place;
    _trackingEngine.onPlaceUpdated(place);
    notifyListeners();
    await loadPlaces();
    _trackingEngine.checkCurrentLocation();
  }

  Future<void> deletePlace(String id) async {
    await _placeRepository.deletePlace(id);
    ++_loadGeneration;
    if (_disposed) return;
    _places.removeWhere((p) => p.id == id);
    _trackingEngine.onPlaceDeleted(id);
    notifyListeners();
    await loadPlaces();
    _trackingEngine.checkCurrentLocation();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_loadGeneration;
    super.dispose();
  }

  Future<void> toggleTracking(Place place) async {
    final updated = place.copyWith(isTrackingEnabled: !place.isTrackingEnabled);
    await updatePlace(updated);
  }

  String formatPlaceDuration(String placeName) {
    final seconds = _placeTotalDurations[placeName] ?? 0;
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}
