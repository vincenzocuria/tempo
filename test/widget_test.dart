import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/data/models/habit_suggestion.dart';
import 'package:tempo/data/models/place.dart';
import 'package:tempo/data/models/place_category.dart';
import 'package:tempo/data/models/visit_session.dart';
import 'package:tempo/data/services/export_service.dart';
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
      expect(parsed['version'], '1.0.4');
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
