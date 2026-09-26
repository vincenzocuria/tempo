import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repositories/place_repository.dart';
import 'data/repositories/visit_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/notification_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.instance.initialize();

  // Initialize database
  await DatabaseService.instance.database;

  // Repositories
  final placeRepo = PlaceRepository();
  final visitRepo = VisitRepository();

  // Tracking Engine
  final trackingEngine = TrackingEngine(
    placeRepository: placeRepo,
    visitRepository: visitRepo,
  );
  await trackingEngine.initialize();

  // Read theme preference - DEFAULT TO LIGHT MODE!
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;

  runApp(
    TempoApp(
      placeRepository: placeRepo,
      visitRepository: visitRepo,
      trackingEngine: trackingEngine,
      initialDarkMode: isDark,
    ),
  );
}

class TempoApp extends StatefulWidget {
  final PlaceRepository placeRepository;
  final VisitRepository visitRepository;
  final TrackingEngine trackingEngine;
  final bool initialDarkMode;

  const TempoApp({
    super.key,
    required this.placeRepository,
    required this.visitRepository,
    required this.trackingEngine,
    required this.initialDarkMode,
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
        ChangeNotifierProvider<TrackingEngine>.value(value: widget.trackingEngine),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            visitRepository: widget.visitRepository,
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
          nextScreen: MainShell(
            isDarkMode: _isDarkMode,
            onThemeToggle: _toggleTheme,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex != index) {
            HapticFeedback.selectionClick();
          }
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Oggi',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mappa',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place_rounded),
            label: 'Luoghi',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Statistiche',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Impostazioni',
          ),
        ],
      ),
    );
  }
}
