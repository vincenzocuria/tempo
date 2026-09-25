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

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  Place? _selectedPlace;
  LatLng _currentLocation = const LatLng(41.9028, 12.4964); // Default Italy (Rome)
  bool _hasLocatedUser = false;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _hasLocatedUser = true;
      });
      _mapController.move(_currentLocation, 15.5);
    }
  }

  void _centerOnUser() async {
    HapticFeedback.lightImpact();
    await _fetchUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    final trackingEngine = Provider.of<TrackingEngine>(context);
    final placesVm = Provider.of<PlacesViewModel>(context);
    final isDark = widget.isDarkMode;

    // CartoDB tiles: voyager for bright modern light, dark_all for sleek dark
    final tileUrl = isDark
        ? 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

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

    // User's live GPS marker
    if (_hasLocatedUser || trackingEngine.lastKnownPosition != null) {
      final userLat = trackingEngine.lastKnownPosition?.latitude ?? _currentLocation.latitude;
      final userLng = trackingEngine.lastKnownPosition?.longitude ?? _currentLocation.longitude;

      markers.add(
        Marker(
          point: LatLng(userLat, userLng),
          width: 32,
          height: 32,
          child: Container(
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
              child: Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
            ),
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
          width: 52,
          height: 52,
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
          // OpenStreetMap with flutter_map
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
                      color: isDark ? AppColors.darkSurface.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
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
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Quick Theme Toggle Button
                      FloatingActionButton.small(
                        heroTag: 'map_theme_toggle',
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                        foregroundColor: isDark ? AppColors.warning : AppColors.primary,
                        elevation: 3,
                        tooltip: isDark ? 'Passa al Tema Chiaro' : 'Passa al Tema Scuro',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onThemeToggle();
                        },
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
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
