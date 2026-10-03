import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';

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
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        if (call.method == 'requestPermissions') {
          return {'3': 0, '4': 0, '17': 0};
        }
        return 0;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async {
        if (call.method == 'isLocationServiceEnabled') return false;
        if (call.method == 'getLastKnownPosition') return null;
        return 0;
      },
    );
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

  testWidgets('TempoApp cold launch test with completed onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final index in [1, 2, 3, 4, 0]) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Page $index must fit on a 360dp screen',
      );
    }
  });
}
