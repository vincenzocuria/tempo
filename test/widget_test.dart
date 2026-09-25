import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/data/models/place.dart';
import 'package:tempo/data/models/place_category.dart';
import 'package:tempo/data/models/visit_session.dart';

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
    });

    test('VisitSession duration calculation', () {
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
    });

    test('PlaceCategory display name and icons', () {
      expect(PlaceCategory.lavoro.displayName, 'Lavoro');
      expect(PlaceCategory.palestra.displayName, 'Palestra & Sport');
      expect(PlaceCategory.casa.displayName, 'Casa');
    });
  });
}
