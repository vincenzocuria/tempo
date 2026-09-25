import '../models/place.dart';
import '../models/place_category.dart';
import '../models/visit_session.dart';
import '../services/database_service.dart';

class VisitRepository {
  final DatabaseService _dbService;

  VisitRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<VisitSession?> getActiveVisit() async {
    return await _dbService.getActiveVisit();
  }

  Future<VisitSession> startVisit(Place place, {DateTime? startTime}) async {
    // Check if there is already an active visit, close it first
    final currentActive = await _dbService.getActiveVisit();
    final now = startTime ?? DateTime.now();

    if (currentActive != null) {
      if (currentActive.placeId == place.id) {
        return currentActive; // Already inside this place
      }
      // Close previous visit
      final closedPrevious = currentActive.copyWith(
        endTime: now,
        durationSeconds: now.difference(currentActive.startTime).inSeconds,
      );
      await _dbService.updateVisit(closedPrevious);
    }

    final newVisit = VisitSession(
      placeId: place.id,
      placeName: place.name,
      category: place.category,
      startTime: now,
      endTime: null,
    );
    await _dbService.insertVisit(newVisit);
    return newVisit;
  }

  Future<VisitSession?> endActiveVisit({DateTime? endTime}) async {
    final active = await _dbService.getActiveVisit();
    if (active == null) return null;

    final end = endTime ?? DateTime.now();
    final closed = active.copyWith(
      endTime: end,
      durationSeconds: end.difference(active.startTime).inSeconds,
    );
    await _dbService.updateVisit(closed);
    return closed;
  }

  Future<void> addManualVisit(VisitSession visit) async {
    await _dbService.insertVisit(visit);
  }

  Future<void> updateVisit(VisitSession visit) async {
    await _dbService.updateVisit(visit);
  }

  Future<void> deleteVisit(String id) async {
    await _dbService.deleteVisit(id);
  }

  Future<List<VisitSession>> getVisits({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    return await _dbService.getVisits(from: from, to: to, limit: limit);
  }

  Future<List<VisitSession>> getTodayVisits() async {
    return await _dbService.getTodayVisits();
  }

  Future<Map<String, int>> getTotalDurationByPlace({
    DateTime? from,
    DateTime? to,
  }) async {
    return await _dbService.getTotalDurationByPlace(from: from, to: to);
  }

  Future<Map<PlaceCategory, int>> getTotalDurationByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    return await _dbService.getTotalDurationByCategory(from: from, to: to);
  }

  Future<Map<String, int>> getDailyDurationsForLastDays(int days) async {
    return await _dbService.getDailyDurationsForLastDays(days);
  }

  Future<void> clearAllData() async {
    await _dbService.clearAllData();
  }

  Future<void> seedDemoData() async {
    await _dbService.seedDemoData();
  }
}
