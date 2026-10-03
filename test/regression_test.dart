import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tempo/data/models/place_category.dart';
import 'package:tempo/data/models/place.dart';
import 'package:tempo/data/models/trip.dart';
import 'package:tempo/data/models/visit_session.dart';
import 'package:tempo/data/services/database_service.dart';
import 'package:tempo/data/services/export_service.dart';
import 'package:tempo/data/services/session_time.dart';
import 'package:tempo/data/repositories/trip_repository.dart';
import 'package:tempo/data/repositories/visit_repository.dart';
import 'package:tempo/ui/features/analytics/analytics_view_model.dart';

VisitSession visit(
  DateTime start,
  DateTime? end, {
  String name = 'Casa',
  String? id,
}) => VisitSession(
  id: id,
  placeId: 'home',
  placeName: name,
  category: PlaceCategory.casa,
  startTime: start,
  endTime: end,
);

void main() {
  final now = DateTime(2026, 9, 26, 12);
  test(
    'Session crossing midnight is clipped and split between calendar days',
    () {
      final start = DateTime(2026, 9, 25, 23);
      final end = DateTime(2026, 9, 26, 2);
      expect(
        SessionTime.seconds(start, end, from: DateTime(2026, 9, 26), now: now),
        7200,
      );
      expect(SessionTime.daily(start, end, now: now), {
        '2026-09-25': 3600,
        '2026-09-26': 7200,
      });
    },
  );
  test(
    'Active session uses live time and rejects future and empty intervals',
    () {
      expect(
        SessionTime.seconds(
          now.subtract(const Duration(minutes: 10)),
          null,
          now: now,
        ),
        600,
      );
      expect(
        SessionTime.seconds(
          now.add(const Duration(minutes: 10)),
          null,
          now: now,
        ),
        0,
      );
      expect(SessionTime.seconds(now, now, now: now), 0);
    },
  );
  test('Closing, editing and reopening visits recalculates duration and clears nullable data', () {
    final v = visit(
      now.subtract(const Duration(hours: 1)),
      null,
    ).copyWith(notes: 'nota');
    final closed = v.copyWith(endTime: now);
    expect(closed.durationSeconds, 3600);
    expect(
      closed
          .copyWith(startTime: now.subtract(const Duration(minutes: 20)))
          .durationSeconds,
      1200,
    );
    expect(closed.copyWith(endTime: null, notes: null).endTime, isNull);
    expect(closed.copyWith(endTime: null, notes: null).notes, isNull);
  });
  test(
    'Deleted places can be detached from trips without losing the saved names',
    () {
      final t = Trip(
        originPlaceId: 'gone',
        originPlaceName: 'Casa',
        destinationPlaceId: 'gone2',
        destinationPlaceName: 'Ufficio',
        startTime: now.subtract(const Duration(minutes: 5)),
      );
      final updated = t.copyWith(
        originPlaceId: null,
        destinationPlaceId: null,
        endTime: now,
      );
      expect(updated.originPlaceId, isNull);
      expect(updated.destinationPlaceId, isNull);
      expect(updated.originPlaceName, 'Casa');
      expect(updated.durationSeconds, 300);
    },
  );
  test('CSV escapes names, quotes, commas and multiline notes', () {
    final v = visit(
      now.subtract(const Duration(minutes: 5)),
      now,
      name: 'Casa "A", B',
    ).copyWith(notes: 'prima\n"seconda"');
    final csv = ExportService.exportVisitsToCsv(visits: [v], places: []);
    expect(csv, contains('"Casa ""A"", B"'));
    expect(csv, contains('"prima\n""seconda"""'));
    expect(csv, contains('"300"'));
  });
  test('JSON includes trips and custom category definitions', () {
    final t = Trip(originPlaceName: 'Casa', startTime: now);
    final data = jsonDecode(
      ExportService.exportDataToJson(
        places: [],
        visits: [],
        trips: [t],
        customCategories: [PlaceCategory.casa],
      ),
    );
    expect(data['trips'].single['id'], t.id);
    expect(data['customCategories'].single['name'], 'casa');
  });

  group('Database date filters and statistics', () {
    late Directory directory;
    final db = DatabaseService.instance;
    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp('tempo-regression-');
      await databaseFactory.setDatabasesPath(directory.path);
    });
    setUp(() async => db.clearAllData());
    tearDownAll(() async {
      await (await db.database).close();
      await directory.delete(recursive: true);
    });
    test(
      'From-only and to-only queries include intersecting sessions',
      () async {
        await db.insertVisit(
          visit(
            DateTime(2026, 9, 25, 23),
            DateTime(2026, 9, 26, 2),
            id: 'cross',
          ),
        );
        await db.insertVisit(
          visit(DateTime(2026, 9, 27), DateTime(2026, 9, 27, 1), id: 'later'),
        );
        final filtered = await db.getVisits(
          from: DateTime(2026, 9, 26),
          to: DateTime(2026, 9, 27),
        );
        expect(filtered.map((v) => v.id), ['cross']);
        expect(
          (await db.getVisits(to: DateTime(2026, 9, 26))).map((v) => v.id),
          ['cross'],
        );
        expect(
          (await db.getTotalDurationByPlace(
            from: DateTime(2026, 9, 26),
            to: DateTime(2026, 9, 27),
          ))['Casa'],
          7200,
        );
      },
    );
    test(
      'Trip aggregates support upper-only filters and midnight clipping',
      () async {
        await db.insertTrip(
          Trip(
            originPlaceName: 'Casa',
            startTime: DateTime(2026, 9, 25, 23),
            endTime: DateTime(2026, 9, 26, 1),
            distanceMeters: 2000,
          ),
        );
        expect(await db.getTotalTripDuration(to: DateTime(2026, 9, 26)), 3600);
        expect(await db.getTotalDistance(from: DateTime(2026, 9, 26)), 1000);
      },
    );
    test(
      'Analytics includes an active session once and matches category totals',
      () async {
        final start = DateTime.now().subtract(const Duration(minutes: 10));
        await db.insertVisit(visit(start, null));
        final vm = AnalyticsViewModel(
          visitRepository: VisitRepository(),
          tripRepository: TripRepository(),
        );
        while (vm.isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        vm.setFilter(AnalyticsTimeFilter.allTime);
        while (vm.isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(vm.categoryStatsList.single.visitCount, 1);
        expect(vm.totalDurationSeconds, greaterThanOrEqualTo(600));
        expect(
          vm.categoryStatsList.single.durationSeconds,
          vm.totalDurationSeconds,
        );
        expect(vm.categoryStatsList.single.percentageOfTotal, 1);
        vm.dispose();
      },
    );
    test(
      'Changing one place name does not rename another place with same name',
      () async {
        // History belongs to IDs, not to an ambiguous display name.
        await db.insertVisit(
          visit(now.subtract(const Duration(hours: 1)), now, id: 'one'),
        );
        final other = visit(
          now.subtract(const Duration(hours: 1)),
          now,
          id: 'two',
        ).copyWith(placeId: 'other');
        await db.insertVisit(other);
        final home = Place(
          id: 'home',
          name: 'Casa',
          category: PlaceCategory.casa,
          latitude: 45,
          longitude: 9,
        );
        await db.insertPlace(home);
        await db.updatePlace(home.copyWith(name: 'Casa nuova'));
        expect(
          (await db.getVisits())
              .where((v) => v.placeId == 'home')
              .single
              .placeName,
          'Casa nuova',
        );
        expect(
          (await db.getVisits())
              .where((v) => v.placeId == 'other')
              .single
              .placeName,
          'Casa',
        );
      },
    );
  });
}
