import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/place_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'data/repositories/visit_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/native_geofence_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/permission_manager.dart';
import 'data/services/tracking_engine.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/analytics/analytics_view.dart';
import 'ui/features/analytics/analytics_view_model.dart';
import 'ui/features/dashboard/dashboard_view.dart';
import 'ui/features/dashboard/dashboard_view_model.dart';
import 'ui/features/history/history_view.dart';
import 'ui/features/map/map_view.dart';
import 'ui/features/places/places_view.dart';
import 'ui/features/places/places_view_model.dart';
import 'ui/features/settings/settings_view.dart';
import 'ui/features/splash/splash_view.dart';
import 'ui/features/onboarding/onboarding_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for Italian locale
  await initializeDateFormatting('it_IT', null);

  // Initialize notifications
  await NotificationService.instance.initialize();

  // Initialize database
  await DatabaseService.instance.database;

  // Repositories
  final placeRepo = PlaceRepository();
  final visitRepo = VisitRepository();
  final tripRepo = TripRepository();
  final categoryRepo = CategoryRepository();
  await categoryRepo.initialize();

  // Tracking Engine
  final trackingEngine = TrackingEngine(
    placeRepository: placeRepo,
    visitRepository: visitRepo,
    tripRepository: tripRepo,
  );
  await trackingEngine.initialize();

  // Read theme preference - DEFAULT TO LIGHT MODE!
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  runApp(
    TempoApp(
      placeRepository: placeRepo,
      visitRepository: visitRepo,
      tripRepository: tripRepo,
      categoryRepository: categoryRepo,
      trackingEngine: trackingEngine,
      initialDarkMode: isDark,
      hasCompletedOnboarding: hasCompletedOnboarding,
    ),
  );

  // Initialize native OS geofencing and sync places with OS subsystem asynchronously
  unawaited(() async {
    try {
      final status = await Permission.locationAlways.status;
      if (status.isGranted) {
        await NativeGeofenceService.instance.initialize();
        final allPlaces = await placeRepo.getAllPlaces();
        await NativeGeofenceService.instance.syncAllPlaces(allPlaces);
      } else {
        debugPrint('[NativeGeofence] Startup sync skipped: locationAlways not granted yet.');
      }
    } catch (e) {
      debugPrint('Native geofence initialization error: $e');
    }
  }());
}

class TempoApp extends StatefulWidget {
  final PlaceRepository placeRepository;
  final VisitRepository visitRepository;
  final TripRepository tripRepository;
  final CategoryRepository categoryRepository;
  final TrackingEngine trackingEngine;
  final bool initialDarkMode;
  final bool hasCompletedOnboarding;

  const TempoApp({
    super.key,
    required this.placeRepository,
    required this.visitRepository,
    required this.tripRepository,
    required this.categoryRepository,
    required this.trackingEngine,
    required this.initialDarkMode,
    required this.hasCompletedOnboarding,
  });

  @override
  State<TempoApp> createState() => _TempoAppState();
}

class _TempoAppState extends State<TempoApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  void _toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PlaceRepository>.value(value: widget.placeRepository),
        Provider<VisitRepository>.value(value: widget.visitRepository),
        Provider<TripRepository>.value(value: widget.tripRepository),
        ChangeNotifierProvider<CategoryRepository>.value(value: widget.categoryRepository),
        ChangeNotifierProvider<TrackingEngine>.value(value: widget.trackingEngine),
        ChangeNotifierProvider<NotificationService>.value(value: NotificationService.instance),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            visitRepository: widget.visitRepository,
            tripRepository: widget.tripRepository,
            trackingEngine: widget.trackingEngine,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PlacesViewModel(
            placeRepository: widget.placeRepository,
            visitRepository: widget.visitRepository,
            trackingEngine: widget.trackingEngine,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsViewModel(
            visitRepository: widget.visitRepository,
            tripRepository: widget.tripRepository,
            trackingEngine: widget.trackingEngine,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Tempo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: SplashView(
          nextScreen: widget.hasCompletedOnboarding
              ? MainShell(
                  isDarkMode: _isDarkMode,
                  onThemeToggle: _toggleTheme,
                )
              : OnboardingView(
                  nextScreen: MainShell(
                    isDarkMode: _isDarkMode,
                    onThemeToggle: _toggleTheme,
                  ),
                ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const MainShell({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkProactivePermissions();
  }

  Future<void> _checkProactivePermissions() async {
    final status = await PermissionManager.instance.checkAllStatus();
    if (!status.locationGranted) {
      await PermissionManager.instance.requestForegroundLocation();
    }
    if (!status.notificationGranted) {
      await PermissionManager.instance.requestNotifications();
    }
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardView(
        onNavigateToHistory: _navigateToHistory,
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
      ),
      MapView(
        isActive: _currentIndex == 1,
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
      ),
      const PlacesView(),
      const AnalyticsView(),
      SettingsView(
        isDarkMode: widget.isDarkMode,
        onThemeToggle: widget.onThemeToggle,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Consumer<TrackingEngine>(
        builder: (context, engine, _) {
          final isInside = engine.activeVisit != null && engine.currentPlace != null;
          final isTraveling = engine.activeTrip != null;

          final Color badgeColor;
          final String tabLabel;

          if (isInside) {
            badgeColor = engine.currentPlace!.color;
            tabLabel = 'Oggi';
          } else if (isTraveling) {
            badgeColor = const Color(0xFF0EA5E9);
            tabLabel = 'In viaggio';
          } else {
            badgeColor = const Color(0xFFF59E0B);
            tabLabel = 'Oggi • Fuori';
          }

          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              if (_currentIndex != index) {
                HapticFeedback.selectionClick();
              }
              setState(() => _currentIndex = index);
            },
            destinations: [
              NavigationDestination(
                icon: Badge(
                  backgroundColor: badgeColor,
                  smallSize: 8,
                  child: const Icon(Icons.dashboard_outlined),
                ),
                selectedIcon: Badge(
                  backgroundColor: badgeColor,
                  smallSize: 9,
                  child: const Icon(Icons.dashboard_rounded),
                ),
                label: tabLabel,
              ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Mappa',
              ),
              const NavigationDestination(
                icon: Icon(Icons.place_outlined),
                selectedIcon: Icon(Icons.place_rounded),
                label: 'Luoghi',
              ),
              const NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                selectedIcon: Icon(Icons.pie_chart_rounded),
                label: 'Statistiche',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Impostazioni',
              ),
            ],
          );
        },
      ),
    );
  }
}
