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
  bool get isLoading => _isLoading;

  PlacesViewModel({
    required PlaceRepository placeRepository,
    required VisitRepository visitRepository,
    required TrackingEngine trackingEngine,
  })  : _placeRepository = placeRepository,
        _visitRepository = visitRepository,
        _trackingEngine = trackingEngine {
    loadPlaces();
  }

  Future<void> loadPlaces({bool forceRefresh = false}) async {
    // Only show full loading spinner if we don't have any places in memory yet
    if (_places.isEmpty || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Fetch places first and display immediately (takes < 2ms)
      _places = await _placeRepository.getAllPlaces();
      _isLoading = false;
      notifyListeners();

      // 2. Fetch duration aggregates in background without delaying list display
      _placeTotalDurations = await _visitRepository.getTotalDurationByPlace();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlace(Place place) async {
    // Deduplication check: ignore if an exact duplicate is already in list
    final existingIndex = _places.indexWhere(
      (p) => p.id == place.id || (p.name.trim().toLowerCase() == place.name.trim().toLowerCase() &&
          (p.latitude - place.latitude).abs() < 0.0001 &&
          (p.longitude - place.longitude).abs() < 0.0001),
    );

    if (existingIndex != -1 && _places[existingIndex].id == place.id) {
      return;
    }

    // Optimistic insert into UI list
    _places.removeWhere((p) => p.id == place.id);
    _places.insert(0, place);
    notifyListeners();

    await _placeRepository.savePlace(place);
    loadPlaces();
    // Fire tracking location check in background without blocking the UI
    _trackingEngine.checkCurrentLocation();
  }

  Future<void> updatePlace(Place place) async {
    final idx = _places.indexWhere((p) => p.id == place.id);
    if (idx != -1) {
      _places[idx] = place;
      notifyListeners();
    }
    await _placeRepository.updatePlace(place);
    _trackingEngine.onPlaceUpdated(place);
    loadPlaces();
    _trackingEngine.checkCurrentLocation();
  }

  Future<void> deletePlace(String id) async {
    // 1. Immediate optimistic removal: disappears from screen in 0ms!
    _places.removeWhere((p) => p.id == id);
    notifyListeners();

    // 2. Notify tracking engine to clear active place/visit if this place was active
    _trackingEngine.onPlaceDeleted(id);

    // 3. Delete from persistent database
    await _placeRepository.deletePlace(id);

    // 4. Background sync without blocking UI
    loadPlaces();
    _trackingEngine.checkCurrentLocation();
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
