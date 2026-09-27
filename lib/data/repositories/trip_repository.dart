import '../models/trip.dart';
import '../services/database_service.dart';

class TripRepository {
  final DatabaseService _dbService;

  TripRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Trip?> getActiveTrip() async {
    try {
      return await _dbService.getActiveTrip();
    } catch (_) {
      return null;
    }
  }

  Future<void> insertTrip(Trip trip) async {
    try {
      await _dbService.insertTrip(trip);
    } catch (_) {}
  }

  Future<void> updateTrip(Trip trip) async {
    try {
      await _dbService.updateTrip(trip);
    } catch (_) {}
  }

  Future<void> deleteTrip(String id) async {
    try {
      await _dbService.deleteTrip(id);
    } catch (_) {}
  }

  Future<List<Trip>> getTrips({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    try {
      return await _dbService.getTrips(from: from, to: to, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<Trip>> getTodayTrips() async {
    try {
      return await _dbService.getTodayTrips();
    } catch (_) {
      return [];
    }
  }

  Future<double> getTotalDistance({DateTime? from, DateTime? to}) async {
    try {
      return await _dbService.getTotalDistance(from: from, to: to);
    } catch (_) {
      return 0.0;
    }
  }

  Future<int> getTotalTripDuration({DateTime? from, DateTime? to}) async {
    try {
      return await _dbService.getTotalTripDuration(from: from, to: to);
    } catch (_) {
      return 0;
    }
  }
}
