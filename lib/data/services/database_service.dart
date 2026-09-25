import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/place.dart';
import '../models/place_category.dart';
import '../models/visit_session.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tempo_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
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
    return await db.update(
      'places',
      place.toMap(),
      where: 'id = ?',
      whereArgs: [place.id],
    );
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

    if (from != null && to != null) {
      whereClause = 'startTime >= ? AND startTime <= ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    } else if (from != null) {
      whereClause = 'startTime >= ?';
      whereArgs = [from.toIso8601String()];
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
    return getVisits(from: startOfDay);
  }

  Future<Map<String, int>> getTotalDurationByPlace({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String query = '''
      SELECT placeName, SUM(durationSeconds) as totalDuration
      FROM visit_sessions
      WHERE endTime IS NOT NULL
    ''';
    List<dynamic> args = [];
    if (from != null && to != null) {
      query += ' AND startTime >= ? AND startTime <= ?';
      args.addAll([from.toIso8601String(), to.toIso8601String()]);
    }
    query += ' GROUP BY placeName ORDER BY totalDuration DESC';

    final result = await db.rawQuery(query, args);
    final map = <String, int>{};
    for (final row in result) {
      final name = row['placeName'] as String;
      final duration = (row['totalDuration'] as num?)?.toInt() ?? 0;
      map[name] = duration;
    }
    return map;
  }

  Future<Map<PlaceCategory, int>> getTotalDurationByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String query = '''
      SELECT category, SUM(durationSeconds) as totalDuration
      FROM visit_sessions
      WHERE endTime IS NOT NULL
    ''';
    List<dynamic> args = [];
    if (from != null && to != null) {
      query += ' AND startTime >= ? AND startTime <= ?';
      args.addAll([from.toIso8601String(), to.toIso8601String()]);
    }
    query += ' GROUP BY category ORDER BY totalDuration DESC';

    final result = await db.rawQuery(query, args);
    final map = <PlaceCategory, int>{};
    for (final row in result) {
      final cat = PlaceCategory.fromString(row['category'] as String?);
      final duration = (row['totalDuration'] as num?)?.toInt() ?? 0;
      map[cat] = duration;
    }
    return map;
  }

  Future<Map<String, int>> getDailyDurationsForLastDays(int days) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

    final query = '''
      SELECT SUBSTR(startTime, 1, 10) as dayDate, SUM(durationSeconds) as totalDuration
      FROM visit_sessions
      WHERE startTime >= ? AND endTime IS NOT NULL
      GROUP BY dayDate
      ORDER BY dayDate ASC
    ''';

    final result = await db.rawQuery(query, [start.toIso8601String()]);
    final map = <String, int>{};
    for (final row in result) {
      final date = row['dayDate'] as String;
      final dur = (row['totalDuration'] as num?)?.toInt() ?? 0;
      map[date] = dur;
    }
    return map;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('visit_sessions');
    await db.delete('places');
  }

  Future<void> seedDemoData() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM places'),
    );
    if (count != null && count > 0) return; // Don't overwrite existing data

    final p1 = Place(
      name: 'Ufficio / Lavoro',
      category: PlaceCategory.lavoro,
      latitude: 45.4642,
      longitude: 9.1900,
      radiusInMeters: 120.0,
      colorValue: 0xFF3B82F6,
    );
    final p2 = Place(
      name: 'Palestra GymFit',
      category: PlaceCategory.palestra,
      latitude: 45.4700,
      longitude: 9.1950,
      radiusInMeters: 80.0,
      colorValue: 0xFF10B981,
    );
    final p3 = Place(
      name: 'Casa',
      category: PlaceCategory.casa,
      latitude: 45.4500,
      longitude: 9.1800,
      radiusInMeters: 100.0,
      colorValue: 0xFFF59E0B,
    );

    await insertPlace(p1);
    await insertPlace(p2);
    await insertPlace(p3);

    final now = DateTime.now();
    // Generate realistic visit data for the last 5 days
    for (int i = 4; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));

      // Work session (e.g. 09:00 to 17:30 or 18:00)
      if (day.weekday <= 5) {
        final workStart = day.add(const Duration(hours: 9, minutes: 15));
        final workEnd = day.add(Duration(hours: 17, minutes: 30 + (i * 10 % 30)));
        await insertVisit(VisitSession(
          placeId: p1.id,
          placeName: p1.name,
          category: p1.category,
          startTime: workStart,
          endTime: workEnd,
          durationSeconds: workEnd.difference(workStart).inSeconds,
        ));
      }

      // Gym session (e.g. 18:30 to 20:00 on Mon, Wed, Fri)
      if (day.weekday == 1 || day.weekday == 3 || day.weekday == 5) {
        final gymStart = day.add(const Duration(hours: 18, minutes: 45));
        final gymEnd = day.add(const Duration(hours: 20, minutes: 15));
        await insertVisit(VisitSession(
          placeId: p2.id,
          placeName: p2.name,
          category: p2.category,
          startTime: gymStart,
          endTime: gymEnd,
          durationSeconds: gymEnd.difference(gymStart).inSeconds,
        ));
      }

      // Home session evening
      final homeStart = day.add(const Duration(hours: 20, minutes: 30));
      final homeEnd = day.add(const Duration(hours: 23, minutes: 45));
      await insertVisit(VisitSession(
        placeId: p3.id,
        placeName: p3.name,
        category: p3.category,
        startTime: homeStart,
        endTime: homeEnd,
        durationSeconds: homeEnd.difference(homeStart).inSeconds,
      ));
    }
  }
}
