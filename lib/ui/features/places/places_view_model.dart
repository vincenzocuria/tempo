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

  Future<void> loadPlaces() async {
    _isLoading = true;
    notifyListeners();

    try {
      _places = await _placeRepository.getAllPlaces();
      _placeTotalDurations = await _visitRepository.getTotalDurationByPlace();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlace(Place place) async {
    await _placeRepository.savePlace(place);
    await loadPlaces();
    await _trackingEngine.checkCurrentLocation();
  }

  Future<void> updatePlace(Place place) async {
    await _placeRepository.updatePlace(place);
    _trackingEngine.onPlaceUpdated(place);
    await loadPlaces();
    await _trackingEngine.checkCurrentLocation();
  }

  Future<void> deletePlace(String id) async {
    await _placeRepository.deletePlace(id);
    await loadPlaces();
    await _trackingEngine.checkCurrentLocation();
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
