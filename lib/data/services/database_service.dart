import 'session_time.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_notification.dart';
import '../models/habit_suggestion.dart';
import '../models/place.dart';
import '../models/place_category.dart';
import '../models/trip.dart';
import '../models/visit_session.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tempo_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createHabitTable(db);
        }
        if (oldVersion < 3) {
          await _createTripsTable(db);
        }
        if (oldVersion < 4) {
          await _createCategoriesTable(db);
        }
        if (oldVersion < 5) {
          await _createNotificationsTable(db);
        }
      },
    );
    return db;
  }

  static Future<void> _syncPlaceNamesInDb(Database db) async {
    try {
      final places = await db.query('places');
      for (final p in places) {
        final id = p['id'] as String;
        final name = p['name'] as String;
        final category = p['category'] as String?;

        final visitUpdates = <String, dynamic>{'placeName': name};
        if (category != null) {
          visitUpdates['category'] = category;
        }

        await db.update(
          'visit_sessions',
          visitUpdates,
          where: 'placeId = ?',
          whereArgs: [id],
        );

        await db.update(
          'trips',
          {'originPlaceName': name},
          where: 'originPlaceId = ?',
          whereArgs: [id],
        );

        await db.update(
          'trips',
          {'destinationPlaceName': name},
          where: 'destinationPlaceId = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      debugPrint('Error syncing place names in history: $e');
    }
  }

  Future<void> syncPlaceNamesInHistory() async {
    final db = await database;
    await _syncPlaceNamesInDb(db);
  }

  static Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        displayName TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isCustom INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createHabitTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_suggestions (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        firstDetected TEXT NOT NULL,
        lastDetected TEXT NOT NULL,
        visitCount INTEGER NOT NULL,
        totalMinutesSpent INTEGER NOT NULL,
        suggestedName TEXT,
        suggestedCategory TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createTripsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        originPlaceId TEXT,
        originPlaceName TEXT NOT NULL,
        destinationPlaceId TEXT,
        destinationPlaceName TEXT,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationSeconds INTEGER NOT NULL,
        distanceMeters REAL NOT NULL,
        transportMode TEXT NOT NULL,
        encodedPoints TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_trip_startTime ON trips(startTime);
    ''');
  }

  static Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL,
        payload TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notification_timestamp ON app_notifications(timestamp);
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE places (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radiusInMeters REAL NOT NULL,
        colorValue INTEGER NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        notifyOnEntry INTEGER NOT NULL,
        notifyOnExit INTEGER NOT NULL,
        isTrackingEnabled INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE visit_sessions (
        id TEXT PRIMARY KEY,
        placeId TEXT NOT NULL,
        placeName TEXT NOT NULL,
        category TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationSeconds INTEGER NOT NULL,
        isManual INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_visit_startTime ON visit_sessions(startTime);
    ''');
    await db.execute('''
      CREATE INDEX idx_visit_placeId ON visit_sessions(placeId);
    ''');

    await _createHabitTable(db);
    await _createTripsTable(db);
    await _createCategoriesTable(db);
    await _createNotificationsTable(db);
  }

  // --- PLACES CRUD ---

  Future<int> insertPlace(Place place) async {
    final db = await database;
    return await db.insert(
      'places',
      place.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Place>> getAllPlaces() async {
    final db = await database;
    final maps = await db.query('places', orderBy: 'createdAt DESC');
    return maps.map((m) => Place.fromMap(m)).toList();
  }

  Future<Place?> getPlaceById(String id) async {
    final db = await database;
    final maps = await db.query('places', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Place.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updatePlace(Place place) async {
    final db = await database;
    final existing = await getPlaceById(place.id);
    final oldName = existing?.name;

    final res = await db.update(
      'places',
      place.toMap(),
      where: 'id = ?',
      whereArgs: [place.id],
    );

    final visitUpdateData = <String, dynamic>{
      'placeName': place.name,
      'category': place.category.name,
    };

    if (oldName != null && oldName.isNotEmpty && oldName != place.name) {
      await db.update(
        'visit_sessions',
        visitUpdateData,
        where: 'placeId = ?',
        whereArgs: [place.id],
      );

      await db.update(
        'trips',
        {'originPlaceName': place.name},
        where: 'originPlaceId = ? OR (originPlaceId IS NULL AND originPlaceName = ?)',
        whereArgs: [place.id, oldName],
      );

      await db.update(
        'trips',
        {'destinationPlaceName': place.name},
        where: 'destinationPlaceId = ? OR (destinationPlaceId IS NULL AND destinationPlaceName = ?)',
        whereArgs: [place.id, oldName],
      );
    } else {
      await db.update(
        'visit_sessions',
        visitUpdateData,
        where: 'placeId = ?',
        whereArgs: [place.id],
      );

      await db.update(
        'trips',
        {'originPlaceName': place.name},
        where: 'originPlaceId = ?',
        whereArgs: [place.id],
      );

      await db.update(
        'trips',
        {'destinationPlaceName': place.name},
        where: 'destinationPlaceId = ?',
        whereArgs: [place.id],
      );
    }

    return res;
  }

  Future<int> deletePlace(String id) async {
    final db = await database;
    return await db.delete('places', where: 'id = ?', whereArgs: [id]);
  }

  // --- VISIT SESSIONS CRUD ---

  Future<int> insertVisit(VisitSession visit) async {
    final db = await database;
    return await db.insert(
      'visit_sessions',
      visit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateVisit(VisitSession visit) async {
    final db = await database;
    return await db.update(
      'visit_sessions',
      visit.toMap(),
      where: 'id = ?',
      whereArgs: [visit.id],
    );
  }

  Future<int> deleteVisit(String id) async {
    final db = await database;
    return await db.delete('visit_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<VisitSession?> getActiveVisit() async {
    final db = await database;
    final maps = await db.query(
      'visit_sessions',
      where: 'endTime IS NULL',
      orderBy: 'startTime DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return VisitSession.fromMap(maps.first);
    }
    return null;
  }

  Future<List<VisitSession>> getVisits({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      conditions.add('(endTime IS NULL OR endTime > ?)');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('startTime < ?');
      args.add(to.toIso8601String());
    }
    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query(
      'visit_sessions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'startTime DESC',
      limit: limit,
    );
    return maps.map((m) => VisitSession.fromMap(m)).toList();
  }

  Future<List<VisitSession>> getTodayVisits() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return getVisits(from: startOfDay, to: now);
  }

  Future<Map<String, int>> getTotalDurationByPlace({
    DateTime? from,
    DateTime? to,
  }) async {
    final visits = await getVisits(from: from, to: to);
    final result = <String, int>{};
    final now = DateTime.now();
    for (final v in visits) {
      final seconds = SessionTime.seconds(
        v.startTime,
        v.endTime,
        from: from,
        to: to,
        now: now,
      );
      if (seconds > 0) {
        result[v.placeName] = (result[v.placeName] ?? 0) + seconds;
      }
    }
    return result;
  }

  Future<Map<PlaceCategory, int>> getTotalDurationByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final visits = await getVisits(from: from, to: to);
    final result = <PlaceCategory, int>{};
    final now = DateTime.now();
    for (final v in visits) {
      final seconds = SessionTime.seconds(
        v.startTime,
        v.endTime,
        from: from,
        to: to,
        now: now,
      );
      if (seconds > 0) result[v.category] = (result[v.category] ?? 0) + seconds;
    }
    return result;
  }

  Future<Map<String, int>> getDailyDurationsForLastDays(int days) async {
    if (days <= 0) return {};
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - days + 1);
    final visits = await getVisits(from: from, to: now);
    final result = <String, int>{};
    for (final v in visits) {
      for (final entry in SessionTime.daily(
        v.startTime,
        v.endTime,
        from: from,
        now: now,
      ).entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    return result;
  }

  // --- HABIT SUGGESTIONS CRUD ---

  Future<int> insertHabitSuggestion(HabitSuggestion suggestion) async {
    final db = await database;
    return await db.insert(
      'habit_suggestions',
      suggestion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateHabitSuggestion(HabitSuggestion suggestion) async {
    final db = await database;
    return await db.update(
      'habit_suggestions',
      suggestion.toMap(),
      where: 'id = ?',
      whereArgs: [suggestion.id],
    );
  }

  Future<List<HabitSuggestion>> getPendingHabitSuggestions() async {
    final db = await database;
    final maps = await db.query(
      'habit_suggestions',
      where: 'status = ? AND visitCount >= 3',
      whereArgs: [HabitStatus.pending.name],
      orderBy: 'visitCount DESC, totalMinutesSpent DESC',
    );
    return maps.map((m) => HabitSuggestion.fromMap(m)).toList();
  }

  /// Pulisce eventuali vecchie proposte derivate da una singola sosta occasionale (< 3 visite)
  Future<void> demoteNonHabitSuggestions() async {
    final db = await database;
    await db.update(
      'habit_suggestions',
      {'status': HabitStatus.learning.name},
      where: 'status = ? AND visitCount < 3',
      whereArgs: [HabitStatus.pending.name],
    );
  }

  Future<int> dismissHabitSuggestion(String id) async {
    final db = await database;
    return await db.update(
      'habit_suggestions',
      {'status': HabitStatus.dismissed.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markHabitSuggestionSaved(String id) async {
    final db = await database;
    return await db.update(
      'habit_suggestions',
      {'status': HabitStatus.saved.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<HabitSuggestion?> findNearbyHabitSuggestion(
    double lat,
    double lng, {
    double maxDistanceMeters = 120.0,
  }) async {
    final db = await database;
    final maps = await db.query('habit_suggestions');
    for (final map in maps) {
      final s = HabitSuggestion.fromMap(map);
      // Simple approximate distance check
      final dLat = (s.latitude - lat).abs() * 111000;
      final dLng = (s.longitude - lng).abs() * 111000 * 0.7;
      final dist = (dLat * dLat + dLng * dLng);
      if (dist <= maxDistanceMeters * maxDistanceMeters) {
        return s;
      }
    }
    return null;
  }

  // --- TRIPS CRUD ---

  Future<int> insertTrip(Trip trip) async {
    final db = await database;
    return await db.insert(
      'trips',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await database;
    return await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<int> deleteTrip(String id) async {
    final db = await database;
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  Future<Trip?> getActiveTrip() async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: 'endTime IS NULL',
      orderBy: 'startTime DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Trip.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Trip>> getTrips({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      conditions.add('(endTime IS NULL OR endTime > ?)');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('startTime < ?');
      args.add(to.toIso8601String());
    }
    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query(
      'trips',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'startTime DESC',
      limit: limit,
    );
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  Future<List<Trip>> getTodayTrips() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return getTrips(from: startOfDay, to: now);
  }

  Future<double> getTotalDistance({DateTime? from, DateTime? to}) async {
    final trips = await getTrips(from: from, to: to);
    final now = DateTime.now();
    return trips.fold<double>(
      0,
      (sum, t) =>
          sum +
          SessionTime.distance(
            t.distanceMeters,
            t.startTime,
            t.endTime,
            from: from,
            to: to,
            now: now,
          ),
    );
  }

  Future<int> getTotalTripDuration({DateTime? from, DateTime? to}) async {
    final trips = await getTrips(from: from, to: to);
    final now = DateTime.now();
    return trips.fold<int>(
      0,
      (sum, t) =>
          sum +
          SessionTime.seconds(
            t.startTime,
            t.endTime,
            from: from,
            to: to,
            now: now,
          ),
    );
  }

  // --- CUSTOM CATEGORIES CRUD ---

  Future<int> insertCustomCategory(PlaceCategory category) async {
    final db = await database;
    final map = category.toMap();
    map['createdAt'] = DateTime.now().toIso8601String();
    return await db.insert(
      'custom_categories',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PlaceCategory>> getAllCustomCategories() async {
    final db = await database;
    final maps = await db.query('custom_categories', orderBy: 'createdAt ASC');
    return maps.map((m) => PlaceCategory.fromMap(m)).toList();
  }

  Future<int> updateCustomCategory(PlaceCategory category) async {
    final db = await database;
    return await db.update(
      'custom_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCustomCategory(String id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'custom_categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return 0;
      final name = rows.first['name'] as String;
      for (final table in ['places', 'visit_sessions']) {
        await txn.update(
          table,
          {'category': PlaceCategory.altro.name},
          where: 'category = ? OR category = ?',
          whereArgs: [id, name],
        );
      }
      return txn.delete('custom_categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'visit_sessions',
        'trips',
        'places',
        'habit_suggestions',
        'custom_categories',
        'app_notifications',
      ]) {
        await txn.delete(table);
      }
    });
  }

  Future<void> seedDemoData() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM places'),
    );
    if (count != null && count > 0) return; // Don't overwrite existing data

    final p1 = Place(
      name: 'Ufficio Principale',
      category: PlaceCategory.lavoro,
      latitude: 45.4642,
      longitude: 9.1900,
      radiusInMeters: 120.0,
      colorValue: 0xFF3B82F6,
    );
    final p2 = Place(
      name: 'Casa Principale',
      category: PlaceCategory.casa,
      latitude: 45.4500,
      longitude: 9.1800,
      radiusInMeters: 100.0,
      colorValue: 0xFFF59E0B,
    );
    final p3 = Place(
      name: 'Seconda Casa',
      category: PlaceCategory.secondaCasa,
      latitude: 45.4850,
      longitude: 9.2100,
      radiusInMeters: 110.0,
      colorValue: 0xFFD97706,
    );

    await insertPlace(p1);
    await insertPlace(p2);
    await insertPlace(p3);

    final now = DateTime.now();
    // Generate realistic visit and trip data for the last 5 days
    for (int i = 4; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));

      // Work session (e.g. 09:15 to 17:30)
      if (day.weekday <= 5) {
        // Morning commute trip: Casa -> Ufficio
        final tripStart = day.add(const Duration(hours: 8, minutes: 45));
        final tripEnd = day.add(const Duration(hours: 9, minutes: 12));
        await insertTrip(
          Trip(
            originPlaceId: p2.id,
            originPlaceName: p2.name,
            destinationPlaceId: p1.id,
            destinationPlaceName: p1.name,
            startTime: tripStart,
            endTime: tripEnd,
            durationSeconds: tripEnd.difference(tripStart).inSeconds,
            distanceMeters: 4200.0,
            transportMode: 'In auto / Mezzo',
            routePoints: [
              TripPoint(
                latitude: 45.4500,
                longitude: 9.1800,
                timestamp: tripStart,
              ),
              TripPoint(
                latitude: 45.4550,
                longitude: 9.1830,
                timestamp: tripStart.add(const Duration(minutes: 8)),
              ),
              TripPoint(
                latitude: 45.4600,
                longitude: 9.1870,
                timestamp: tripStart.add(const Duration(minutes: 18)),
              ),
              TripPoint(
                latitude: 45.4642,
                longitude: 9.1900,
                timestamp: tripEnd,
              ),
            ],
          ),
        );

        final workStart = day.add(const Duration(hours: 9, minutes: 15));
        final workEnd = day.add(
          Duration(hours: 17, minutes: 30 + (i * 10 % 30)),
        );
        await insertVisit(
          VisitSession(
            placeId: p1.id,
            placeName: p1.name,
            category: p1.category,
            startTime: workStart,
            endTime: workEnd,
            durationSeconds: workEnd.difference(workStart).inSeconds,
          ),
        );

        // Evening commute trip: Ufficio -> Casa
        final returnTripStart = workEnd.add(const Duration(minutes: 5));
        final returnTripEnd = returnTripStart.add(const Duration(minutes: 32));
        await insertTrip(
          Trip(
            originPlaceId: p1.id,
            originPlaceName: p1.name,
            destinationPlaceId: p2.id,
            destinationPlaceName: p2.name,
            startTime: returnTripStart,
            endTime: returnTripEnd,
            durationSeconds: returnTripEnd
                .difference(returnTripStart)
                .inSeconds,
            distanceMeters: 4400.0,
            transportMode: 'In auto / Mezzo',
            routePoints: [
              TripPoint(
                latitude: 45.4642,
                longitude: 9.1900,
                timestamp: returnTripStart,
              ),
              TripPoint(
                latitude: 45.4590,
                longitude: 9.1860,
                timestamp: returnTripStart.add(const Duration(minutes: 10)),
              ),
              TripPoint(
                latitude: 45.4540,
                longitude: 9.1820,
                timestamp: returnTripStart.add(const Duration(minutes: 20)),
              ),
              TripPoint(
                latitude: 45.4500,
                longitude: 9.1800,
                timestamp: returnTripEnd,
              ),
            ],
          ),
        );
      }

      // Second home or weekend
      if (day.weekday == 6 || day.weekday == 7) {
        final secStart = day.add(const Duration(hours: 11, minutes: 0));
        final secEnd = day.add(const Duration(hours: 18, minutes: 30));
        await insertVisit(
          VisitSession(
            placeId: p3.id,
            placeName: p3.name,
            category: p3.category,
            startTime: secStart,
            endTime: secEnd,
            durationSeconds: secEnd.difference(secStart).inSeconds,
          ),
        );
      }

      // Home session evening
      final homeStart = day.add(const Duration(hours: 20, minutes: 0));
      final homeEnd = day.add(const Duration(hours: 23, minutes: 30));
      await insertVisit(
        VisitSession(
          placeId: p2.id,
          placeName: p2.name,
          category: p2.category,
          startTime: homeStart,
          endTime: homeEnd,
          durationSeconds: homeEnd.difference(homeStart).inSeconds,
        ),
      );
    }
  }

  // --- APP NOTIFICATIONS CRUD ---

  Future<int> insertNotification(AppNotification notification) async {
    final db = await database;
    // Assicura che la tabella esista anche se creata al volo
    await _createNotificationsTable(db);
    return await db.insert(
      'app_notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppNotification>> getNotifications({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    await _createNotificationsTable(db);
    final maps = await db.query(
      'app_notifications',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => AppNotification.fromMap(m)).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final db = await database;
    await _createNotificationsTable(db);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM app_notifications WHERE isRead = 0',
    );
    if (result.isNotEmpty) {
      return (result.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<int> markNotificationAsRead(String id) async {
    final db = await database;
    await _createNotificationsTable(db);
    return await db.update(
      'app_notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllNotificationsAsRead() async {
    final db = await database;
    await _createNotificationsTable(db);
    return await db.update('app_notifications', {
      'isRead': 1,
    }, where: 'isRead = 0');
  }

  Future<int> deleteNotification(String id) async {
    final db = await database;
    await _createNotificationsTable(db);
    return await db.delete(
      'app_notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllNotifications() async {
    final db = await database;
    await _createNotificationsTable(db);
    return await db.delete('app_notifications');
  }
}
