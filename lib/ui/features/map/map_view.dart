import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../places/place_form_dialog.dart';
import '../places/places_view_model.dart';

enum MapLayerType {
  osm,
  cartoVoyager,
  cartoDark;

  String get displayName {
    switch (this) {
      case MapLayerType.osm:
        return 'Stradale Dettagliata (OSM)';
      case MapLayerType.cartoVoyager:
        return 'Moderna Chiara (CartoDB)';
      case MapLayerType.cartoDark:
        return 'Notturna OLED (CartoDB Dark)';
    }
  }

  String get tileUrl {
    switch (this) {
      case MapLayerType.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapLayerType.cartoVoyager:
        return 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
      case MapLayerType.cartoDark:
        return 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}@2x.png';
    }
  }
}

class MapView extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const MapView({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Place? _selectedPlace;
  LatLng _currentLocation = const LatLng(41.9028, 12.4964); // Default Italy (Rome)
  bool _hasLocatedUser = false;
  MapLayerType? _customLayerType;

  late AnimationController _beaconController;
  late Animation<double> _beaconRadiusAnim;
  late Animation<double> _beaconOpacityAnim;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();

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

  @override
  void dispose() {
    _beaconController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _hasLocatedUser = true;
      });
      try {
        _mapController.move(_currentLocation, 15.5);
      } catch (_) {}
    }
  }

  void _centerOnUser() async {
    HapticFeedback.lightImpact();
    await _fetchUserLocation();
  }

  void _fitAllPlaces(List<Place> places) {
    HapticFeedback.lightImpact();
    if (places.isEmpty) return;

    if (places.length == 1) {
      _mapController.move(
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
    _mapController.move(center, 13.0);
  }

  void _showLayerSelector(BuildContext context, bool isDark) {
    final currentType = _customLayerType ?? (isDark ? MapLayerType.cartoDark : MapLayerType.osm);
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
                      layer == MapLayerType.osm
                          ? Icons.map_rounded
                          : (layer == MapLayerType.cartoVoyager ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded),
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

    final activeLayer = _customLayerType ?? (isDark ? MapLayerType.cartoDark : MapLayerType.osm);
    final tileUrl = activeLayer.tileUrl;

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

    // Build markers for places
    final markers = <Marker>[];

    // User's live GPS marker with animated pulsing beacon
    if (_hasLocatedUser || trackingEngine.lastKnownPosition != null) {
      final userLat = trackingEngine.lastKnownPosition?.latitude ?? _currentLocation.latitude;
      final userLng = trackingEngine.lastKnownPosition?.longitude ?? _currentLocation.longitude;

      markers.add(
        Marker(
          point: LatLng(userLat, userLng),
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: _beaconController,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer expanding radar pulse
                  Container(
                    width: 26 * _beaconRadiusAnim.value,
                    height: 26 * _beaconRadiusAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: _beaconOpacityAnim.value),
                    ),
                  ),
                  // Central GPS core dot
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.navigation_rounded, color: Colors.white, size: 12),
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
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPlace = place;
              });
              _mapController.move(
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

    return Scaffold(
      body: Stack(
        children: [
          // Genuine interactive Map Layer (OpenStreetMap / CartoDB)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.5,
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
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.tempo.app.tempo',
              ),
              CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),

          // Top Header overlay
          SafeArea(
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
                          'Mappa Luoghi (${placesVm.places.length})',
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
                      // Map Layer Selector (OSM / CartoDB)
                      FloatingActionButton.small(
                        heroTag: 'map_layer_selector',
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 3,
                        tooltip: 'Stile Mappa (Stradale / Scura)',
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
                        const SizedBox(width: 8),
                      ],
                      // Recenter on GPS
                      FloatingActionButton.small(
                        heroTag: 'map_recenter_user',
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 3,
                        tooltip: 'Mia Posizione',
                        onPressed: _centerOnUser,
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Zoom in / Zoom out floating controls on right side
          Positioned(
            right: 16,
            bottom: _selectedPlace != null ? 220 : 96,
            child: Container(
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
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
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
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Selected Place Card Bottom Sheet
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
      ),
      floatingActionButton: _selectedPlace == null
          ? FloatingActionButton.extended(
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
            )
          : null,
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
