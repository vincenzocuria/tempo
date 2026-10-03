import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tempo/data/repositories/category_repository.dart';
import 'package:tempo/data/repositories/place_repository.dart';
import 'package:tempo/data/repositories/trip_repository.dart';
import 'package:tempo/data/repositories/visit_repository.dart';
import 'package:tempo/data/services/tracking_engine.dart';
import 'package:tempo/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  testWidgets('TempoApp cold launch test without onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final placeRepo = PlaceRepository();
    final visitRepo = VisitRepository();
    final tripRepo = TripRepository();
    final categoryRepo = CategoryRepository();
    final trackingEngine = TrackingEngine(
      placeRepository: placeRepo,
      visitRepository: visitRepo,
      tripRepository: tripRepo,
    );

    await tester.pumpWidget(
      TempoApp(
        placeRepository: placeRepo,
        visitRepository: visitRepo,
        tripRepository: tripRepo,
        categoryRepository: categoryRepo,
        trackingEngine: trackingEngine,
        initialDarkMode: false,
        hasCompletedOnboarding: false,
      ),
    );

    // Initial frame renders SplashView
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('TempoApp cold launch test with completed onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});

    final placeRepo = PlaceRepository();
    final visitRepo = VisitRepository();
    final tripRepo = TripRepository();
    final categoryRepo = CategoryRepository();
    final trackingEngine = TrackingEngine(
      placeRepository: placeRepo,
      visitRepository: visitRepo,
      tripRepository: tripRepo,
    );

    await tester.pumpWidget(
      TempoApp(
        placeRepository: placeRepo,
        visitRepository: visitRepo,
        tripRepository: tripRepo,
        categoryRepository: categoryRepo,
        trackingEngine: trackingEngine,
        initialDarkMode: false,
        hasCompletedOnboarding: true,
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
  });
}
