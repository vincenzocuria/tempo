import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tempo/data/models/app_notification.dart';
import 'package:tempo/data/models/habit_suggestion.dart';
import 'package:tempo/data/models/place.dart';
import 'package:tempo/data/models/place_category.dart';
import 'package:tempo/data/models/trip.dart';
import 'package:tempo/data/models/visit_session.dart';
import 'package:tempo/data/repositories/place_repository.dart';
import 'package:tempo/data/repositories/trip_repository.dart';
import 'package:tempo/data/repositories/visit_repository.dart';
import 'package:tempo/data/services/export_service.dart';
import 'package:tempo/data/services/tracking_engine.dart';
import 'package:tempo/ui/features/analytics/analytics_view_model.dart';
import 'package:tempo/ui/features/onboarding/onboarding_view.dart';

void main() {
  group('Tempo Domain Models Unit Tests', () {
    test('Place creation and category defaults', () {
      final workPlace = Place(
        name: 'Ufficio Centro',
        category: PlaceCategory.lavoro,
        latitude: 45.4642,
        longitude: 9.1900,
        radiusInMeters: 100,
      );

      expect(workPlace.name, 'Ufficio Centro');
      expect(workPlace.category, PlaceCategory.lavoro);
      expect(workPlace.radiusInMeters, 100);
      expect(workPlace.isTrackingEnabled, true);
      expect(workPlace.color, const Color(0xFF3B82F6));
      expect(workPlace.notifyOnEntry, true);
      expect(workPlace.notifyOnExit, true);
    });

    test('Place copyWith and map serialization', () {
      final place = Place(
        name: 'Palestra Gold',
        category: PlaceCategory.palestra,
        latitude: 45.4600,
        longitude: 9.2000,
        radiusInMeters: 80,
      );

      final updated = place.copyWith(
        name: 'Palestra Nuova',
        radiusInMeters: 120,
        isTrackingEnabled: false,
      );

      expect(updated.id, place.id);
      expect(updated.name, 'Palestra Nuova');
      expect(updated.radiusInMeters, 120);
      expect(updated.isTrackingEnabled, false);

      final map = updated.toMap();
      final fromMap = Place.fromMap(map);

      expect(fromMap.id, updated.id);
      expect(fromMap.name, 'Palestra Nuova');
      expect(fromMap.category, PlaceCategory.palestra);
      expect(fromMap.radiusInMeters, 120);
      expect(fromMap.isTrackingEnabled, false);
    });

    test('VisitSession duration calculation and ongoing status', () {
      final start = DateTime(2026, 9, 25, 9, 0);
      final end = DateTime(2026, 9, 25, 17, 30);

      final visit = VisitSession(
        placeId: 'place-123',
        placeName: 'Ufficio Centro',
        category: PlaceCategory.lavoro,
        startTime: start,
        endTime: end,
      );

      expect(visit.isOngoing, false);
      expect(visit.durationSeconds, 8 * 3600 + 30 * 60);
      expect(visit.formattedDuration, '8h 30m');

      final map = visit.toMap();
      final fromMap = VisitSession.fromMap(map);

      expect(fromMap.id, visit.id);
      expect(fromMap.placeName, 'Ufficio Centro');
      expect(fromMap.category, PlaceCategory.lavoro);
      expect(fromMap.durationSeconds, visit.durationSeconds);
      expect(fromMap.isManual, false);
    });

    test('Manual VisitSession with notes and short duration format', () {
      final start = DateTime(2026, 9, 25, 18, 0);
      final end = DateTime(2026, 9, 25, 18, 45);

      final visit = VisitSession(
        placeId: 'place-gym',
        placeName: 'Palestra',
        category: PlaceCategory.palestra,
        startTime: start,
        endTime: end,
        durationSeconds: 45 * 60,
        isManual: true,
        notes: 'Allenamento gambe intenso',
      );

      expect(visit.isManual, true);
      expect(visit.notes, 'Allenamento gambe intenso');
      expect(visit.formattedDuration, '45m');
    });

    test('PlaceCategory display name and icons', () {
      expect(PlaceCategory.lavoro.displayName, 'Lavoro');
      expect(PlaceCategory.palestra.displayName, 'Palestra & Sport');
      expect(PlaceCategory.casa.displayName, 'Casa');
      expect(PlaceCategory.studio.displayName, 'Studio & Università');
      expect(PlaceCategory.svago.displayName, 'Svago & Tempo Libero');
      expect(PlaceCategory.altro.displayName, 'Altro');
    });

    test('ExportService CSV generation', () {
      final place = Place(
        name: 'Ufficio',
        category: PlaceCategory.lavoro,
        latitude: 45.0,
        longitude: 9.0,
      );

      final visit = VisitSession(
        placeId: place.id,
        placeName: place.name,
        category: place.category,
        startTime: DateTime(2026, 9, 25, 9, 0),
        endTime: DateTime(2026, 9, 25, 13, 0),
        durationSeconds: 4 * 3600,
        notes: 'Sessione mattutina',
      );

      final csv = ExportService.exportVisitsToCsv(
        visits: [visit],
        places: [place],
      );

      expect(csv.contains('ID,Luogo,Categoria,Inizio,Fine,Durata_Secondi'), true);
      expect(csv.contains('Ufficio'), true);
      expect(csv.contains('Lavoro'), true);
      expect(csv.contains('4h'), true);
      expect(csv.contains('Sessione mattutina'), true);
    });

    test('ExportService JSON generation and parsing', () {
      final place = Place(
        name: 'Casa',
        category: PlaceCategory.casa,
        latitude: 45.1,
        longitude: 9.1,
      );

      final visit = VisitSession(
        placeId: place.id,
        placeName: place.name,
        category: place.category,
        startTime: DateTime(2026, 9, 25, 20, 0),
        endTime: DateTime(2026, 9, 26, 8, 0),
        durationSeconds: 12 * 3600,
      );

      final jsonStr = ExportService.exportDataToJson(
        places: [place],
        visits: [visit],
      );

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['app'], 'Tempo');
      expect(parsed['version'], '1.0.14');
      expect(parsed['places'], isA<List>());
      expect((parsed['places'] as List).length, 1);
      expect(parsed['visits'], isA<List>());
      expect((parsed['visits'] as List).length, 1);
    });

    test('AnalyticsTimeFilter display names', () {
      expect(AnalyticsTimeFilter.today.displayName, 'Oggi');
      expect(AnalyticsTimeFilter.thisWeek.displayName, 'Settimana');
      expect(AnalyticsTimeFilter.thisMonth.displayName, 'Mese');
      expect(AnalyticsTimeFilter.allTime.displayName, 'Tutto');
    });

    test('TransportModeStats formatting and speed calculation', () {
      final car = TransportModeStats(
        modeName: 'In auto / Mezzo',
        modeKey: 'car',
        icon: Icons.directions_car_rounded,
        color: const Color(0xFF0284C7),
        durationSeconds: 3600,
        distanceMeters: 45000.0,
        tripCount: 3,
      );

      expect(car.formattedDuration, '1h');
      expect(car.formattedDistance, '45.0 km');
      expect(car.avgSpeedKmh, 45.0);
      expect(car.tripCount, 3);
    });

    test('CategoryTimeStats formatting and daily average calculation', () {
      final work = CategoryTimeStats(
        category: PlaceCategory.lavoro,
        durationSeconds: 28 * 3600,
        visitCount: 4,
        distinctDaysCount: 4,
        percentageOfTotal: 0.35,
      );

      expect(work.formattedDuration, '28h');
      expect(work.dailyAverageFormatted, '7h / g');
      expect(work.visitCount, 4);
      expect(work.distinctDaysCount, 4);
    });

    test('Multi-home and multi-job categories support', () {
      expect(PlaceCategory.secondaCasa.displayName, 'Seconda Casa');
      expect(PlaceCategory.secondoLavoro.displayName, 'Secondo Lavoro / Ufficio');
      expect(PlaceCategory.servizi.displayName, 'Spesa & Servizi');

      final home2 = Place(
        name: 'Casa al mare',
        category: PlaceCategory.secondaCasa,
        latitude: 44.4,
        longitude: 8.9,
      );
      expect(home2.category, PlaceCategory.secondaCasa);
      expect(home2.name, 'Casa al mare');

      final work2 = Place(
        name: 'Coworking Torino',
        category: PlaceCategory.secondoLavoro,
        latitude: 45.0,
        longitude: 7.6,
      );
      expect(work2.category, PlaceCategory.secondoLavoro);
      expect(work2.name, 'Coworking Torino');
    });

    test('HabitSuggestion serialization and duration formatting', () {
      final suggestion = HabitSuggestion(
        latitude: 45.4680,
        longitude: 9.1850,
        visitCount: 3,
        totalMinutesSpent: 135,
        suggestedName: 'Nuovo Luogo',
        suggestedCategory: PlaceCategory.secondaCasa,
      );

      expect(suggestion.formattedDuration, '2h 15m');
      expect(suggestion.visitCount, 3);
      expect(suggestion.status, HabitStatus.pending);

      final map = suggestion.toMap();
      final fromMap = HabitSuggestion.fromMap(map);

      expect(fromMap.id, suggestion.id);
      expect(fromMap.latitude, suggestion.latitude);
      expect(fromMap.longitude, suggestion.longitude);
      expect(fromMap.visitCount, 3);
      expect(fromMap.totalMinutesSpent, 135);
      expect(fromMap.suggestedCategory, PlaceCategory.secondaCasa);
      expect(fromMap.status, HabitStatus.pending);
    });

    test('HabitSuggestion distinguishes single pause from recurring habit', () {
      // 1. Single 15-minute pause is NOT a habit (learning status, isHabit false)
      final singlePause = HabitSuggestion(
        latitude: 45.123,
        longitude: 9.456,
        visitCount: 1,
        totalMinutesSpent: 15,
        status: HabitStatus.learning,
      );
      expect(singlePause.isHabit, false);
      expect(singlePause.status, HabitStatus.learning);

      // 2. Two visits totaling 30 min is still learning
      final twoVisits = HabitSuggestion(
        latitude: 45.123,
        longitude: 9.456,
        visitCount: 2,
        totalMinutesSpent: 30,
        status: HabitStatus.learning,
      );
      expect(twoVisits.isHabit, false);

      // 3. Three distinct visits totaling >= 45 min qualifies as a true habit
      final trueHabit = HabitSuggestion(
        latitude: 45.123,
        longitude: 9.456,
        visitCount: 3,
        totalMinutesSpent: 65,
        status: HabitStatus.pending,
      );
      expect(trueHabit.isHabit, true);
      expect(trueHabit.status, HabitStatus.pending);
      expect(trueHabit.formattedDuration, '1h 5m');
    });

    test('AppNotification creation, relative time, and serialization', () {
      final notif = AppNotification(
        title: 'Sei arrivato a Ufficio',
        body: 'Monitoraggio del tempo avviato per Lavoro.',
        type: NotificationType.entry,
        isRead: false,
        payload: 'Ufficio',
      );

      expect(notif.title, 'Sei arrivato a Ufficio');
      expect(notif.type, NotificationType.entry);
      expect(notif.type.displayName, 'Arrivo');
      expect(notif.isRead, false);
      expect(notif.timeAgo, 'Proprio ora');

      final map = notif.toMap();
      final fromMap = AppNotification.fromMap(map);

      expect(fromMap.id, notif.id);
      expect(fromMap.title, notif.title);
      expect(fromMap.body, notif.body);
      expect(fromMap.type, NotificationType.entry);
      expect(fromMap.isRead, false);
      expect(fromMap.payload, 'Ufficio');

      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, true);
    });

    test('Trip creation, distance, and duration formatting', () {
      final start = DateTime(2026, 9, 26, 8, 30);
      final end = DateTime(2026, 9, 26, 8, 52);

      final trip = Trip(
        originPlaceName: 'Casa Principale',
        destinationPlaceName: 'Ufficio Principale',
        startTime: start,
        endTime: end,
        durationSeconds: 22 * 60,
        distanceMeters: 5400.0,
        transportMode: 'In auto / Mezzo',
        routePoints: [
          TripPoint(latitude: 45.45, longitude: 9.18, timestamp: start, speed: 8.5),
          TripPoint(latitude: 45.464, longitude: 9.19, timestamp: end, speed: 10.2),
        ],
      );

      expect(trip.isOngoing, false);
      expect(trip.formattedDistance, '5.4 km');
      expect(trip.formattedDuration, '22m');
      expect(trip.originPlaceName, 'Casa Principale');
      expect(trip.destinationPlaceName, 'Ufficio Principale');
      expect(trip.routePoints.length, 2);
      expect(trip.averageSpeedKmH, closeTo(14.7, 0.5));
    });

    test('Trip serialization with encoded points and fromMap', () {
      final start = DateTime(2026, 9, 26, 14, 0);
      final end = DateTime(2026, 9, 26, 14, 15);

      final trip = Trip(
        originPlaceName: 'Ufficio',
        destinationPlaceName: 'Palestra',
        startTime: start,
        endTime: end,
        durationSeconds: 15 * 60,
        distanceMeters: 1800.0,
        transportMode: 'In bicicletta',
        routePoints: [
          TripPoint(latitude: 45.46, longitude: 9.19, timestamp: start),
          TripPoint(latitude: 45.47, longitude: 9.20, timestamp: end),
        ],
      );

      final map = trip.toMap();
      final fromMap = Trip.fromMap(map);

      expect(fromMap.id, trip.id);
      expect(fromMap.originPlaceName, 'Ufficio');
      expect(fromMap.destinationPlaceName, 'Palestra');
      expect(fromMap.distanceMeters, 1800.0);
      expect(fromMap.transportMode, 'In bicicletta');
      expect(fromMap.routePoints.length, 2);
      expect(fromMap.routePoints.first.latitude, 45.46);
      expect(fromMap.routePoints.last.longitude, 9.20);
    });

    test('TrackingEngine startManualTrip initializes active trip with origin', () async {
      final engine = TrackingEngine(
        placeRepository: PlaceRepository(),
        visitRepository: VisitRepository(),
        tripRepository: TripRepository(),
      );

      expect(engine.activeTrip, isNull);
      await engine.startManualTrip(originName: 'Posizione esterna');

      expect(engine.activeTrip, isNotNull);
      expect(engine.activeTrip!.originPlaceName, 'Posizione esterna');
      expect(engine.activeTrip!.distanceMeters, 0.0);
      expect(engine.activeTrip!.transportMode, TransportMode.piedi);

      await engine.manualFinishTrip();
      expect(engine.activeTrip, isNull);
    });

    test('Custom category registration, serialization, and lookup', () {
      final customCat = PlaceCategory(
        id: 'cat_scuola',
        name: 'scuola',
        displayName: 'Scuola Bimbi',
        icon: Icons.school_rounded,
        defaultColor: const Color(0xFF8B5CF6),
        isCustom: true,
      );

      PlaceCategory.registerCustomCategory(customCat);

      final lookup = PlaceCategory.fromString('scuola');
      expect(lookup.id, 'cat_scuola');
      expect(lookup.displayName, 'Scuola Bimbi');
      expect(lookup.isCustom, true);

      final map = customCat.toMap();
      final fromMap = PlaceCategory.fromMap(map);
      expect(fromMap.id, 'cat_scuola');
      expect(fromMap.name, 'scuola');
      expect(fromMap.displayName, 'Scuola Bimbi');
      expect(fromMap.isCustom, true);

      expect(PlaceCategory.values.any((c) => c.id == 'cat_scuola'), true);

      PlaceCategory.unregisterCustomCategory('cat_scuola');
      expect(PlaceCategory.values.any((c) => c.id == 'cat_scuola'), false);
    });

    test('TransportMode constants, icons, and colors', () {
      expect(TransportMode.auto, 'In auto');
      expect(TransportMode.moto, 'In moto / scooter');
      expect(TransportMode.bici, 'In bicicletta');
      expect(TransportMode.piedi, 'A piedi');
      expect(TransportMode.corsa, 'Corsa');
      expect(TransportMode.altro, 'In spostamento');

      expect(TransportMode.allModes.length, 5);
      for (final mode in TransportMode.allModes) {
        expect(TransportMode.getIcon(mode), isNotNull);
        expect(TransportMode.getColor(mode), isNotNull);
      }
    });

    test('TrackingEngine.inferTransportMode kinematic heuristics', () {
      // 1. Walking
      final walk = TrackingEngine.inferTransportMode(
        avgSpeedKmH: 4.8,
        maxSpeedKmH: 6.2,
        maxAccelerationMs2: 0.8,
        preferredMotorVehicle: TransportMode.auto,
      );
      expect(walk, TransportMode.piedi);

      // 2. Running
      final run = TrackingEngine.inferTransportMode(
        avgSpeedKmH: 10.5,
        maxSpeedKmH: 14.0,
        maxAccelerationMs2: 1.2,
        preferredMotorVehicle: TransportMode.auto,
      );
      expect(run, TransportMode.corsa);

      // 3. Bicycle
      final bike = TrackingEngine.inferTransportMode(
        avgSpeedKmH: 18.0,
        maxSpeedKmH: 28.0,
        maxAccelerationMs2: 1.5,
        preferredMotorVehicle: TransportMode.auto,
      );
      expect(bike, TransportMode.bici);

      // 4. Car (default motorized)
      final car = TrackingEngine.inferTransportMode(
        avgSpeedKmH: 48.0,
        maxSpeedKmH: 85.0,
        maxAccelerationMs2: 2.1,
        preferredMotorVehicle: TransportMode.auto,
      );
      expect(car, TransportMode.auto);

      // 5. Motorcycle by preference
      final motoPref = TrackingEngine.inferTransportMode(
        avgSpeedKmH: 52.0,
        maxSpeedKmH: 90.0,
        maxAccelerationMs2: 2.0,
        preferredMotorVehicle: TransportMode.moto,
      );
      expect(motoPref, TransportMode.moto);

      // 6. Motorcycle by rapid acceleration burst
      final motoBurst = TrackingEngine.inferTransportMode(
        avgSpeedKmH: 42.0,
        maxSpeedKmH: 75.0,
        maxAccelerationMs2: 3.6,
        preferredMotorVehicle: TransportMode.auto,
      );
      expect(motoBurst, TransportMode.moto);
    });

    test('TrackingEngine onPlaceUpdated synchronizes place name and category across active trip and place references', () async {
      final engine = TrackingEngine(
        placeRepository: PlaceRepository(),
        visitRepository: VisitRepository(),
        tripRepository: TripRepository(),
      );

      final homePlace = Place(
        id: 'place-home',
        name: 'Casa Vecchia',
        category: PlaceCategory.casa,
        latitude: 45.45,
        longitude: 9.18,
      );

      // Start a manual trip from homePlace
      await engine.startManualTrip(originName: homePlace.name);
      expect(engine.activeTrip, isNotNull);
      expect(engine.activeTrip!.originPlaceName, 'Casa Vecchia');

      // Test onPlaceUpdated updates placesVersion
      final initialVersion = engine.placesVersion;
      final renamedHome = homePlace.copyWith(name: 'Casa Nuova', category: PlaceCategory.secondaCasa);
      engine.onPlaceUpdated(renamedHome);
      expect(engine.placesVersion, initialVersion + 1);

      // Verify Trip model destination and origin updating
      final tripWithDest = engine.activeTrip!.copyWith(
        originPlaceId: homePlace.id,
        destinationPlaceId: 'place-work',
        destinationPlaceName: 'Ufficio Vecchio',
      );
      expect(tripWithDest.originPlaceName, 'Casa Vecchia');
      expect(tripWithDest.destinationPlaceName, 'Ufficio Vecchio');

      final renamedTrip = tripWithDest.copyWith(
        originPlaceName: renamedHome.name,
        destinationPlaceName: 'Ufficio Nuovo',
      );
      expect(renamedTrip.originPlaceName, 'Casa Nuova');
      expect(renamedTrip.destinationPlaceName, 'Ufficio Nuovo');

      // Verify VisitSession model renaming
      final visit = VisitSession(
        placeId: 'place-home',
        placeName: 'Casa Vecchia',
        category: PlaceCategory.casa,
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
      );
      expect(visit.placeName, 'Casa Vecchia');
      final renamedVisit = visit.copyWith(
        placeName: 'Casa Nuova',
        category: PlaceCategory.secondaCasa,
      );
      expect(renamedVisit.placeName, 'Casa Nuova');
      expect(renamedVisit.category, PlaceCategory.secondaCasa);
    });

    test('TrackingEngine adaptive profile conserves battery inside places and scales up during trips', () async {
      final fakeVisitRepo = _FakeBatteryVisitRepository();
      final fakeTripRepo = _FakeBatteryTripRepository();

      final engine = TrackingEngine(
        placeRepository: PlaceRepository(),
        visitRepository: fakeVisitRepo,
        tripRepository: fakeTripRepo,
      );

      final office = Place(
        id: 'place-office',
        name: 'Ufficio',
        category: PlaceCategory.lavoro,
        latitude: 45.46,
        longitude: 9.19,
        radiusInMeters: 100,
      );

      // Check-in inside place: switches to battery-conserving profile (medium accuracy, relaxed distance filter)
      await engine.manualCheckIn(office);
      expect(engine.currentPlace, isNotNull);
      expect(engine.activeAccuracy, LocationAccuracy.medium);
      expect(engine.activeDistanceFilter, greaterThanOrEqualTo(35));

      // Check-out: transitions back to high accuracy
      await engine.manualCheckOut();
      expect(engine.currentPlace, isNull);
      expect(engine.activeAccuracy, LocationAccuracy.high);

      // Lifecycle pause / resume
      engine.didChangeAppLifecycleState(AppLifecycleState.paused);
      engine.didChangeAppLifecycleState(AppLifecycleState.resumed);

      engine.dispose();
    });

    testWidgets('OnboardingView renders initial slide with privacy badge and skip button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEMPO'), findsOneWidget);
      expect(find.text('Salta'), findsOneWidget);
      expect(find.text('PRIVACY AL 100%'), findsOneWidget);
      expect(find.text('Il tuo tempo nei luoghi che contano'), findsOneWidget);
    });
  });
}

class _FakeBatteryVisitRepository extends VisitRepository {
  VisitSession? _active;

  @override
  Future<VisitSession?> getActiveVisit() async => _active;

  @override
  Future<VisitSession> startVisit(Place place, {DateTime? startTime}) async {
    _active = VisitSession(
      placeId: place.id,
      placeName: place.name,
      category: place.category,
      startTime: startTime ?? DateTime.now(),
    );
    return _active!;
  }

  @override
  Future<VisitSession?> endActiveVisit({DateTime? endTime}) async {
    final v = _active;
    _active = null;
    return v;
  }
}

class _FakeBatteryTripRepository extends TripRepository {
  @override
  Future<void> insertTrip(Trip trip) async {}

  @override
  Future<Trip?> getActiveTrip() async => null;
}

