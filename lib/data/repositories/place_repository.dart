import '../models/place.dart';
import '../services/database_service.dart';

class PlaceRepository {
  final DatabaseService _dbService;

  PlaceRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Place>> getAllPlaces() async {
    return await _dbService.getAllPlaces();
  }

  Future<Place?> getPlaceById(String id) async {
    return await _dbService.getPlaceById(id);
  }

  Future<void> savePlace(Place place) async {
    await _dbService.insertPlace(place);
  }

  Future<void> updatePlace(Place place) async {
    await _dbService.updatePlace(place);
  }

  Future<void> deletePlace(String id) async {
    await _dbService.deletePlace(id);
  }

  Future<void> syncPlaceNamesInHistory() async {
    await _dbService.syncPlaceNamesInHistory();
  }
}
