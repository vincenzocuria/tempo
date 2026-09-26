import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/models/trip.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../places/place_form_dialog.dart';
import '../places/places_view_model.dart';

enum MapLayerType {
  osm,
  hot,
  dark,
  topo;

  String get displayName {
    switch (this) {
      case MapLayerType.osm:
        return 'OpenStreetMap Classica';
      case MapLayerType.hot:
        return 'Stradale Dettagliata (OSM HOT)';
      case MapLayerType.dark:
        return 'Notturna OLED (Ad alto contrasto)';
      case MapLayerType.topo:
        return 'Topografica Rilievi (OpenTopoMap)';
    }
  }

  String get tileUrl {
    switch (this) {
      case MapLayerType.osm:
      case MapLayerType.dark:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapLayerType.hot:
        return 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
      case MapLayerType.topo:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  String get fallbackUrl {
    switch (this) {
      case MapLayerType.osm:
      case MapLayerType.dark:
        return 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
      case MapLayerType.hot:
      case MapLayerType.topo:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  List<String> get subdomains {
    switch (this) {
      case MapLayerType.osm:
      case MapLayerType.dark:
        return const ['a', 'b', 'c'];
      case MapLayerType.hot:
      case MapLayerType.topo:
        return const ['a', 'b', 'c'];
    }
  }

  bool get isDark => this == MapLayerType.dark;
}

enum MapFollowMode {
  none,            // Mappa libera (spostata manualmente con gesture)
  follow,          // Centra e segui in tempo reale (Nord in alto)
  followAndRotate, // Bussola / Navigazione: la mappa si orienta verso la direzione di marcia
}

class MapView extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final bool isActive;

  const MapView({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    this.isActive = true,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Place? _selectedPlace;
  LatLng _currentLocation = const LatLng(41.9028, 12.4964); // Fallback iniziale
  bool _hasLocatedUser = false;
  double _mapRotation = 0.0;
  MapLayerType? _customLayerType;
  List<Trip> _todayTrips = [];
  bool _showTripsOnMap = true;

  // Google Maps Follow & Live Tracking States
  MapFollowMode _followMode = MapFollowMode.follow;
  StreamSubscription<Position>? _positionStreamSub;
  AnimationController? _moveAnimController;
  double _currentHeading = 0.0;
  double _currentSpeedKmh = 0.0;
  double _currentAccuracy = 0.0;
  final List<LatLng> _recentBreadcrumbs = [];

  late AnimationController _beaconController;
  late Animation<double> _beaconRadiusAnim;
  late Animation<double> _beaconOpacityAnim;

  @override
  void initState() {
    super.initState();
    _initInitialLocation();
    _fetchUserLocation();
    _startForegroundLocationStream();
    _loadTrips();

    // Radar pulse animation for GPS beacon
    _beaconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _beaconRadiusAnim = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _beaconController, curve: Curves.easeOutCubic),
    );

    _beaconOpacityAnim = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _beaconController, curve: Curves.easeOutCubic),
    );
  }

  void _initInitialLocation() {
    try {
      final engine = Provider.of<TrackingEngine>(context, listen: false);
      if (engine.lastKnownPosition != null) {
        _currentLocation = LatLng(
          engine.lastKnownPosition!.latitude,
          engine.lastKnownPosition!.longitude,
        );
        _hasLocatedUser = true;
        return;
      }
    } catch (_) {}

    try {
      final placesVm = Provider.of<PlacesViewModel>(context, listen: false);
      if (placesVm.places.isNotEmpty) {
        _currentLocation = LatLng(
          placesVm.places.first.latitude,
          placesVm.places.first.longitude,
        );
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Just became visible in IndexedStack
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _hasLocatedUser
            ? _currentLocation
            : (context.read<PlacesViewModel>().places.isNotEmpty
                ? LatLng(
                    context.read<PlacesViewModel>().places.first.latitude,
                    context.read<PlacesViewModel>().places.first.longitude,
                  )
                : _currentLocation);
        _safeMove(target, 16.0);
      });
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _beaconController.dispose();
    _moveAnimController?.dispose();
    super.dispose();
  }

  void _startForegroundLocationStream() {
    _positionStreamSub?.cancel();
    try {
      _positionStreamSub = LocationService.instance
          .getPositionStream(
            distanceFilterMeters: 2,
            accuracy: LocationAccuracy.high,
          )
          .listen(
            _onForegroundPosition,
            onError: (err) {
              debugPrint('Foreground location stream error: $err');
            },
          );
    } catch (e) {
      debugPrint('Error starting position stream: $e');
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180.0);
    final startLng = start.longitude * (pi / 180.0);
    final endLat = end.latitude * (pi / 180.0);
    final endLng = end.longitude * (pi / 180.0);

    final dLng = endLng - startLng;
    final y = sin(dLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);
    final radians = atan2(y, x);
    return (radians * (180.0 / pi) + 360.0) % 360.0;
  }

  void _onForegroundPosition(Position pos) {
    if (!mounted) return;

    final newPoint = LatLng(pos.latitude, pos.longitude);
    final speedKmh = (pos.speed.isNaN || pos.speed <= 0) ? 0.0 : pos.speed * 3.6;
    final accuracy = (pos.accuracy.isNaN || pos.accuracy <= 0) ? 0.0 : pos.accuracy;

    double heading = (pos.heading.isNaN || pos.heading < 0) ? 0.0 : pos.heading;
    if (heading <= 0.0 && _hasLocatedUser) {
      final dist = LocationService.instance.calculateDistance(
        _currentLocation.latitude,
        _currentLocation.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= 1.5) {
        heading = _calculateBearing(_currentLocation, newPoint);
      } else {
        heading = _currentHeading;
      }
    }

    // Accumulate live breadcrumb trail
    if (_recentBreadcrumbs.isEmpty ||
        LocationService.instance.calculateDistance(
          _recentBreadcrumbs.last.latitude,
          _recentBreadcrumbs.last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        ) >= 3.0) {
      _recentBreadcrumbs.add(newPoint);
      if (_recentBreadcrumbs.length > 150) {
        _recentBreadcrumbs.removeAt(0);
      }
    }

    setState(() {
      _currentLocation = newPoint;
      _currentHeading = heading;
      _currentSpeedKmh = speedKmh;
      _currentAccuracy = accuracy;
      _hasLocatedUser = true;
    });

    // Auto-glide camera if follow mode is active
    double zoom = 16.0;
    try {
      zoom = _mapController.camera.zoom;
    } catch (_) {}

    if (_followMode == MapFollowMode.follow) {
      _safeMove(newPoint, zoom);
    } else if (_followMode == MapFollowMode.followAndRotate) {
      final targetRot = heading > 0 ? (360.0 - heading) % 360.0 : 0.0;
      _safeMove(newPoint, zoom, destRotation: targetRot);
    }
  }

  Future<void> _fetchUserLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      final safeHeading = (pos.heading.isNaN || pos.heading < 0) ? 0.0 : pos.heading;
      final safeAccuracy = (pos.accuracy.isNaN || pos.accuracy < 0) ? 0.0 : pos.accuracy;
      final safeSpeed = (pos.speed.isNaN || pos.speed < 0) ? 0.0 : pos.speed * 3.6;
      final newLoc = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentLocation = newLoc;
        _hasLocatedUser = true;
        _currentSpeedKmh = safeSpeed;
        _currentHeading = safeHeading;
        _currentAccuracy = safeAccuracy;
      });
      _safeMove(newLoc, 16.0);
    }
  }

  Future<void> _loadTrips() async {
    try {
      final tripRepo = Provider.of<TripRepository>(context, listen: false);
      final trips = await tripRepo.getTodayTrips();
      if (mounted) {
        setState(() => _todayTrips = trips);
      }
    } catch (_) {}
  }

  void _safeMove(LatLng destLocation, double destZoom, {double? destRotation, bool animate = true}) {
    if (!mounted) return;

    try {
      if (!animate || !widget.isActive) {
        _mapController.move(destLocation, destZoom);
        if (destRotation != null) {
          _mapController.rotate(destRotation);
        }
        return;
      }

      _moveAnimController?.dispose();
      _moveAnimController = null;

      final camera = _mapController.camera;
      final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
      final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
      final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);
      final rotTween = destRotation != null
          ? Tween<double>(begin: camera.rotation, end: destRotation)
          : null;

      final controller = AnimationController(
        duration: const Duration(milliseconds: 380),
        vsync: this,
      );
      _moveAnimController = controller;

      final animation = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

      controller.addListener(() {
        if (!mounted) return;
        try {
          final rot = rotTween?.evaluate(animation);
          _mapController.move(
            LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
            zoomTween.evaluate(animation),
          );
          if (rot != null) {
            _mapController.rotate(rot);
          }
        } catch (_) {}
      });

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          controller.dispose();
          if (_moveAnimController == controller) {
            _moveAnimController = null;
          }
        }
      });

      controller.forward();
    } catch (e) {
      // Direct move fallback if animation controller or camera throws
      try {
        _mapController.move(destLocation, destZoom);
        if (destRotation != null) {
          _mapController.rotate(destRotation);
        }
      } catch (_) {}
    }
  }

  void _toggleFollowMode() {
    HapticFeedback.mediumImpact();
    if (_followMode == MapFollowMode.none) {
      // Re-center and engage follow
      setState(() => _followMode = MapFollowMode.follow);
      _safeMove(_currentLocation, 16.5);
    } else if (_followMode == MapFollowMode.follow) {
      // Engage Follow + Compass rotation
      setState(() => _followMode = MapFollowMode.followAndRotate);
      if (_currentHeading > 0) {
        _safeMove(_currentLocation, 16.5, destRotation: (360.0 - _currentHeading) % 360.0);
      }
    } else {
      // Reset rotation and go back to North-up follow
      _resetNorth();
      setState(() => _followMode = MapFollowMode.follow);
    }
  }

  void _resetNorth() {
    HapticFeedback.lightImpact();
    try {
      final camera = _mapController.camera;
      if (camera.rotation != 0.0) {
        _safeMove(camera.center, camera.zoom, destRotation: 0.0);
      }
      setState(() {
        _mapRotation = 0.0;
        if (_followMode == MapFollowMode.followAndRotate) {
          _followMode = MapFollowMode.follow;
        }
      });
    } catch (_) {}
  }

  void _fitAllPlaces(List<Place> places) {
    HapticFeedback.lightImpact();
    if (places.isEmpty) return;

    setState(() => _followMode = MapFollowMode.none);

    if (places.length == 1) {
      _safeMove(
        LatLng(places.first.latitude, places.first.longitude),
        16.0,
      );
      return;
    }

    double minLat = places.first.latitude;
    double maxLat = places.first.latitude;
    double minLng = places.first.longitude;
    double maxLng = places.first.longitude;

    for (final p in places) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _safeMove(center, 13.5);
  }

  void _fitTripOnMap(Trip trip) {
    HapticFeedback.lightImpact();
    final points = <LatLng>[
      ...trip.latLngPoints,
      _currentLocation,
    ];
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _safeMove(center, 14.5);
    setState(() => _followMode = MapFollowMode.none);
  }

  void _showLayerSelector(BuildContext context, bool isDark) {
    final currentType = _customLayerType ?? (isDark ? MapLayerType.dark : MapLayerType.osm);
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scegli Stile Mappa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...MapLayerType.values.map((layer) {
                final isSelected = currentType == layer;
                final IconData layerIcon;
                switch (layer) {
                  case MapLayerType.osm:
                    layerIcon = Icons.public_rounded;
                    break;
                  case MapLayerType.hot:
                    layerIcon = Icons.map_rounded;
                    break;
                  case MapLayerType.dark:
                    layerIcon = Icons.dark_mode_rounded;
                    break;
                  case MapLayerType.topo:
                    layerIcon = Icons.terrain_rounded;
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                        : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : borderColor,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      layerIcon,
                      color: isSelected ? AppColors.primary : textMuted,
                    ),
                    title: Text(
                      layer.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.primary : textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _customLayerType = layer);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingEngine = Provider.of<TrackingEngine>(context);
    final placesVm = Provider.of<PlacesViewModel>(context);
    final isDark = widget.isDarkMode;

    final activeLayer = _customLayerType ?? (isDark ? MapLayerType.dark : MapLayerType.osm);

    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;

    // Build geofence circles for each place
    final circles = placesVm.places.map((place) {
      final isSelected = _selectedPlace?.id == place.id;
      final isCurrent = trackingEngine.currentPlace?.id == place.id;

      return CircleMarker(
        point: LatLng(place.latitude, place.longitude),
        radius: place.radiusInMeters,
        useRadiusInMeter: true,
        color: place.color.withValues(alpha: isCurrent ? 0.35 : (isSelected ? 0.28 : 0.15)),
        borderColor: place.color,
        borderStrokeWidth: isCurrent || isSelected ? 2.5 : 1.5,
      );
    }).toList();

    // Accuracy halo around user location (Google Maps style)
    if (_hasLocatedUser && _currentAccuracy > 0 && !_currentAccuracy.isNaN) {
      circles.add(
        CircleMarker(
          point: _currentLocation,
          radius: _currentAccuracy.clamp(12.0, 45.0),
          useRadiusInMeter: true,
          color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
          borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.35),
          borderStrokeWidth: 1.0,
        ),
      );
    }

    // Build polylines for recorded trips & active live movements
    final polylines = <Polyline>[];
    if (_showTripsOnMap) {
      // 1. Completed trips today
      for (final trip in _todayTrips) {
        if (trip.routePoints.length >= 2) {
          polylines.add(
            Polyline(
              points: trip.latLngPoints,
              color: const Color(0xFF0284C7).withValues(alpha: 0.8),
              strokeWidth: 4.5,
              borderColor: Colors.white.withValues(alpha: 0.65),
              borderStrokeWidth: 1.5,
            ),
          );
        }
      }

      // 2. Active live trip / displacement (Google Maps real-time trace)
      final activeTrip = trackingEngine.activeTrip;
      if (activeTrip != null) {
        final activePoints = [
          ...trackingEngine.activeRoutePoints.map((p) => p.toLatLng()),
          if (_hasLocatedUser) _currentLocation,
        ];
        if (activePoints.length >= 2) {
          polylines.add(
            Polyline(
              points: activePoints,
              color: const Color(0xFF0EA5E9), // Google Maps Sky Blue
              strokeWidth: 6.0,
              borderColor: Colors.white,
              borderStrokeWidth: 2.0,
            ),
          );
        }
      } else if (_recentBreadcrumbs.length >= 2 && trackingEngine.currentPlace == null) {
        // Real-time breadcrumb footsteps when walking/moving outside places
        polylines.add(
          Polyline(
            points: [..._recentBreadcrumbs, if (_hasLocatedUser) _currentLocation],
            color: const Color(0xFF38BDF8).withValues(alpha: 0.85),
            strokeWidth: 4.5,
            borderColor: Colors.white.withValues(alpha: 0.6),
            borderStrokeWidth: 1.5,
          ),
        );
      }
    }

    // Build markers
    final markers = <Marker>[];

    // Trip origin start pin
    final activeTrip = trackingEngine.activeTrip;
    if (activeTrip != null && trackingEngine.activeRoutePoints.isNotEmpty) {
      final startPt = trackingEngine.activeRoutePoints.first.toLatLng();
      markers.add(
        Marker(
          point: startPt,
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF10B981), // Emerald green origin
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.trip_origin_rounded, color: Colors.white, size: 16),
          ),
        ),
      );
    }

    // User's live GPS marker with Google Maps styling (accuracy halo, heading beam, core dot)
    if (_hasLocatedUser || trackingEngine.lastKnownPosition != null) {
      final userLat = _currentLocation.latitude;
      final userLng = _currentLocation.longitude;

      markers.add(
        Marker(
          point: LatLng(userLat, userLng),
          width: 90,
          height: 90,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _beaconController,
            builder: (context, _) {
              final isMoving = _currentSpeedKmh > 2.5;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Google Maps Directional Heading Beam (illuminates forward)
                  if (_currentHeading > 0)
                    Transform.rotate(
                      angle: _currentHeading * (pi / 180.0),
                      child: const CustomPaint(
                        size: Size(90, 90),
                        painter: _HeadingBeamPainter(color: Color(0xFF38BDF8)),
                      ),
                    ),

                  // 2. Outer expanding radar pulse
                  Container(
                    width: 28 * _beaconRadiusAnim.value,
                    height: 28 * _beaconRadiusAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: _beaconOpacityAnim.value * 0.6),
                    ),
                  ),

                  // 3. Central GPS core dot (Google Maps style)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB), // Google Maps Blue
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.55),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isMoving
                          ? Transform.rotate(
                              angle: _currentHeading * (pi / 180.0),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            )
                          : Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // Place markers
    for (final place in placesVm.places) {
      final isSelected = _selectedPlace?.id == place.id;
      final isCurrent = trackingEngine.currentPlace?.id == place.id;

      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          width: 54,
          height: 54,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPlace = place;
                _followMode = MapFollowMode.none;
              });
              _safeMove(
                LatLng(place.latitude, place.longitude),
                16.0,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: place.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: isCurrent || isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: place.color.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    place.icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    place.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // 1. Genuine interactive Map Layer (OpenStreetMap / OSM HOT / Topo)
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.5,
              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              onMapReady: () {
                if (mounted) {
                  try {
                    setState(() {
                      _mapRotation = _mapController.camera.rotation;
                    });
                  } catch (_) {}
                  if (_hasLocatedUser) {
                    _safeMove(_currentLocation, 16.0);
                  } else if (placesVm.places.isNotEmpty) {
                    _safeMove(
                      LatLng(placesVm.places.first.latitude, placesVm.places.first.longitude),
                      15.5,
                    );
                  }
                }
              },
              onPositionChanged: (camera, hasGesture) {
                // If user drags or pinches map, disengage auto-follow mode
                if (hasGesture && _followMode != MapFollowMode.none) {
                  setState(() => _followMode = MapFollowMode.none);
                }
                if (camera.rotation != _mapRotation) {
                  setState(() => _mapRotation = camera.rotation);
                }
              },
              onTap: (_, __) {
                if (_selectedPlace != null) {
                  setState(() => _selectedPlace = null);
                }
              },
              onLongPress: (_, point) {
                HapticFeedback.mediumImpact();
                PlaceFormDialog.show(context, initialLocation: point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: activeLayer.tileUrl,
                fallbackUrl: activeLayer.fallbackUrl,
                subdomains: activeLayer.subdomains,
                userAgentPackageName: 'com.tempo.app.tempo',
                maxZoom: 20,
                maxNativeZoom: 19,
                tileBuilder: activeLayer.isDark ? darkModeTileBuilder : null,
              ),
              PolylineLayer(polylines: polylines),
              CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),
        ),

        // 2. Top Header overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Mappa (${placesVm.places.length} luoghi)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Toggle Routes/Trips on map
                      FloatingActionButton.small(
                        heroTag: 'map_toggle_trips',
                        backgroundColor: _showTripsOnMap
                            ? const Color(0xFF0EA5E9)
                            : (isDark ? AppColors.darkSurface : Colors.white),
                        foregroundColor: _showTripsOnMap ? Colors.white : textPrimary,
                        elevation: 3,
                        tooltip: _showTripsOnMap ? 'Nascondi percorsi' : 'Mostra percorsi',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showTripsOnMap = !_showTripsOnMap);
                        },
                        child: const Icon(Icons.route_rounded),
                      ),
                      const SizedBox(width: 8),
                      // Map Layer Selector
                      FloatingActionButton.small(
                        heroTag: 'map_layer_selector',
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 3,
                        tooltip: 'Stile Mappa (Classica / Scura / Rilievi)',
                        onPressed: () => _showLayerSelector(context, isDark),
                        child: const Icon(Icons.layers_rounded),
                      ),
                      const SizedBox(width: 8),
                      // Fit all places
                      if (placesVm.places.isNotEmpty) ...[
                        FloatingActionButton.small(
                          heroTag: 'map_fit_places',
                          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                          foregroundColor: textPrimary,
                          elevation: 3,
                          tooltip: 'Inquadra tutti i luoghi',
                          onPressed: () => _fitAllPlaces(placesVm.places),
                          child: const Icon(Icons.crop_free_rounded),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Live Displacement / Movement Navigation HUD (Google Maps style)
        if (trackingEngine.isInTransit || activeTrip != null || (_currentSpeedKmh > 3.5 && trackingEngine.currentPlace == null))
          Positioned(
            top: 64,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: _LiveMovementHud(
                isDark: isDark,
                speedKmh: _currentSpeedKmh,
                activeTrip: activeTrip,
                currentPlace: trackingEngine.currentPlace,
                isFollowing: _followMode != MapFollowMode.none,
                onToggleFollow: _toggleFollowMode,
                onFitTrip: activeTrip != null && activeTrip.routePoints.isNotEmpty
                    ? () => _fitTripOnMap(activeTrip)
                    : null,
              ),
            ),
          ),

        // 4. Floating Controls Column on Right (Compass, Zoom In/Out, Google Maps Recenter FAB)
        Positioned(
          right: 16,
          bottom: _selectedPlace != null ? 240 : 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Compass Needle button (visible when rotation != 0)
              if (_mapRotation.abs() > 1.0) ...[
                _buildCompassButton(isDark, _mapRotation),
                const SizedBox(height: 12),
              ],

              // Zoom controls container
              _buildZoomControls(isDark),
              const SizedBox(height: 14),

              // Dedicated Google Maps Recenter & Follow FAB
              _buildRecenterFollowFab(isDark),
            ],
          ),
        ),

        // 5. FAB: Nuovo Luogo (on bottom-left, when no place is selected)
        if (_selectedPlace == null)
          Positioned(
            left: 16,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'map_add_place_fab',
              onPressed: () {
                HapticFeedback.lightImpact();
                PlaceFormDialog.show(
                  context,
                  initialLocation: _hasLocatedUser ? _currentLocation : null,
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Nuovo Luogo', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),

        // 6. Selected Place Card Bottom Sheet
        if (_selectedPlace != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _PlaceDetailCard(
              place: _selectedPlace!,
              isDark: isDark,
              isCurrentPlace: trackingEngine.currentPlace?.id == _selectedPlace!.id,
              totalTimeStr: placesVm.formatPlaceDuration(_selectedPlace!.name),
              onCheckIn: () {
                HapticFeedback.mediumImpact();
                trackingEngine.manualCheckIn(_selectedPlace!);
                setState(() => _selectedPlace = null);
              },
              onEdit: () {
                final p = _selectedPlace!;
                setState(() => _selectedPlace = null);
                PlaceFormDialog.show(context, placeToEdit: p);
              },
              onClose: () => setState(() => _selectedPlace = null),
            ),
          ),
      ],
    );
  }

  Widget _buildCompassButton(bool isDark, double rotation) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        iconSize: 22,
        tooltip: 'Reimposta Nord in alto',
        onPressed: _resetNorth,
        icon: Transform.rotate(
          angle: -rotation * (pi / 180.0),
          child: const Icon(
            Icons.explore_rounded,
            color: Color(0xFFEF4444), // Compass Red
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'Zoom avanti',
            onPressed: () {
              HapticFeedback.selectionClick();
              try {
                final currentZoom = _mapController.camera.zoom;
                final center = _mapController.camera.center;
                _mapController.move(center, (currentZoom + 1).clamp(1.0, 20.0));
              } catch (_) {}
            },
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            tooltip: 'Zoom indietro',
            onPressed: () {
              HapticFeedback.selectionClick();
              try {
                final currentZoom = _mapController.camera.zoom;
                final center = _mapController.camera.center;
                _mapController.move(center, (currentZoom - 1).clamp(1.0, 20.0));
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecenterFollowFab(bool isDark) {
    final isFollowing = _followMode == MapFollowMode.follow;
    final isCompass = _followMode == MapFollowMode.followAndRotate;
    final isActive = isFollowing || isCompass;

    String tooltip = 'Centra e segui posizione';
    if (isFollowing) {
      tooltip = 'Seguimento attivo • Tocca per modalità bussola';
    } else if (isCompass) {
      tooltip = 'Bussola attiva • Tocca per Nord in alto';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.black12,
              blurRadius: isActive ? 12 : 8,
              offset: const Offset(0, 3),
              spreadRadius: isActive ? 1 : 0,
            ),
          ],
        ),
        child: Material(
          color: isActive
              ? (isCompass ? const Color(0xFF4F46E5) : AppColors.primary)
              : (isDark ? AppColors.darkSurface : Colors.white),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggleFollowMode,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isActive)
                    AnimatedBuilder(
                      animation: _beaconController,
                      builder: (context, _) {
                        return Container(
                          width: 46 + (8 * _beaconRadiusAnim.value),
                          height: 46 + (8 * _beaconRadiusAnim.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: _beaconOpacityAnim.value * 0.7),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                  Icon(
                    isCompass
                        ? Icons.explore_rounded
                        : (isFollowing
                            ? Icons.gps_fixed_rounded
                            : Icons.my_location_outlined),
                    color: isActive
                        ? Colors.white
                        : (isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadingBeamPainter extends CustomPainter {
  final Color color;

  const _HeadingBeamPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 - (35 * pi / 180),
        70 * pi / 180,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadingBeamPainter oldDelegate) => false;
}

class _LiveMovementHud extends StatelessWidget {
  final bool isDark;
  final double speedKmh;
  final Trip? activeTrip;
  final Place? currentPlace;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback? onFitTrip;

  const _LiveMovementHud({
    required this.isDark,
    required this.speedKmh,
    required this.activeTrip,
    required this.currentPlace,
    required this.isFollowing,
    required this.onToggleFollow,
    this.onFitTrip,
  });

  @override
  Widget build(BuildContext context) {
    IconData modeIcon = Icons.directions_walk_rounded;
    String modeLabel = 'A piedi';

    final mode = activeTrip?.transportMode;
    if (mode != null) {
      if (mode.contains('auto') || mode.contains('Mezzo')) {
        modeIcon = Icons.directions_car_rounded;
        modeLabel = 'In auto / Mezzo';
      } else if (mode.contains('bici')) {
        modeIcon = Icons.directions_bike_rounded;
        modeLabel = 'In bicicletta';
      } else {
        modeIcon = Icons.directions_walk_rounded;
        modeLabel = 'A piedi';
      }
    } else if (speedKmh > 22.0) {
      modeIcon = Icons.directions_car_rounded;
      modeLabel = 'In auto';
    } else if (speedKmh > 7.0) {
      modeIcon = Icons.directions_bike_rounded;
      modeLabel = 'In bici';
    }

    final distanceStr = activeTrip?.formattedDistance ?? '0 m';
    final durationStr = activeTrip?.formattedDuration ?? '0s';
    final originName = activeTrip?.originPlaceName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(modeIcon, color: const Color(0xFF0EA5E9), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        originName != null ? 'Da $originName' : 'In Spostamento',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textLightPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        modeLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${speedKmh.toStringAsFixed(0)} km/h • $distanceStr • $durationStr',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (onFitTrip != null) ...[
            IconButton(
              icon: const Icon(Icons.fullscreen_rounded, size: 20),
              tooltip: 'Inquadra percorso',
              onPressed: onFitTrip,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceDetailCard extends StatelessWidget {
  final Place place;
  final bool isDark;
  final bool isCurrentPlace;
  final String totalTimeStr;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  const _PlaceDetailCard({
    required this.place,
    required this.isDark,
    required this.isCurrentPlace,
    required this.totalTimeStr,
    required this.onCheckIn,
    required this.onEdit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: place.color.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: place.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(place.icon, color: place.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            place.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textLightPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentPlace) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: place.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SEI QUI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${place.category.displayName} • Raggio ${place.radiusInMeters.toInt()}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Totale: $totalTimeStr',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textLightPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Modifica',
                onPressed: onEdit,
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: place.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isCurrentPlace ? null : onCheckIn,
                icon: Icon(isCurrentPlace ? Icons.check_circle_rounded : Icons.touch_app_rounded, size: 16),
                label: Text(isCurrentPlace ? 'Attivo' : 'Check-in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
