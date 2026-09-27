import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/visit_session.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import 'transport_mode_picker.dart';

abstract class DayTimelineEvent {
  DateTime get time;
}

class DayTimelineVisit extends DayTimelineEvent {
  final VisitSession visit;
  final Place? place;
  final int stopNumber;

  DayTimelineVisit({
    required this.visit,
    this.place,
    required this.stopNumber,
  });

  @override
  DateTime get time => visit.startTime;
}

class DayTimelineTrip extends DayTimelineEvent {
  final Trip trip;

  DayTimelineTrip(this.trip);

  @override
  DateTime get time => trip.startTime;
}

class DayTimelineView extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialTripId;

  const DayTimelineView({
    super.key,
    this.initialDate,
    this.initialTripId,
  });

  @override
  State<DayTimelineView> createState() => _DayTimelineViewState();
}

class _DayTimelineViewState extends State<DayTimelineView> with TickerProviderStateMixin {
  late DateTime _selectedDate;
  final MapController _mapController = MapController();

  List<VisitSession> _visits = [];
  List<Trip> _trips = [];
  Map<String, Place> _placeMap = {};
  List<DayTimelineEvent> _timelineEvents = [];

  bool _isLoading = true;
  dynamic _selectedItem; // VisitSession or Trip

  double _totalDistanceMeters = 0.0;
  int _totalMovingDurationSeconds = 0;
  int _totalStationaryDurationSeconds = 0;

  AnimationController? _cameraAnimController;

  DateTime? _lastLiveRefresh;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.initialDate != null
        ? DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day)
        : DateTime(now.year, now.month, now.day);
    _loadDayData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          Provider.of<TrackingEngine>(context, listen: false).addListener(_onTrackingEngineUpdated);
        } catch (_) {}
      }
    });
  }

  void _onTrackingEngineUpdated() {
    if (!mounted || !_isToday) return;
    final now = DateTime.now();
    if (_lastLiveRefresh != null && now.difference(_lastLiveRefresh!).inSeconds < 3) {
      return;
    }
    _lastLiveRefresh = now;
    _loadDayData(silent: true);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadDayData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);
    final tripRepo = Provider.of<TripRepository>(context, listen: false);
    final trackingEngine = Provider.of<TrackingEngine>(context, listen: false);

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final allPlaces = await placeRepo.getAllPlaces();
    final pMap = <String, Place>{};
    for (final p in allPlaces) {
      pMap[p.id] = p;
    }

    final rawVisits = await visitRepo.getVisits(from: startOfDay, to: endOfDay);
    final rawTrips = await tripRepo.getTrips(from: startOfDay, to: endOfDay);

    final visits = List<VisitSession>.from(rawVisits);
    final trips = List<Trip>.from(rawTrips);

    // If viewing today, also incorporate active visit or active trip if running
    if (_isToday) {
      final activeVisit = trackingEngine.activeVisit;
      if (activeVisit != null) {
        visits.removeWhere((v) => v.id == activeVisit.id);
        visits.add(activeVisit);
      }
      final activeTrip = trackingEngine.activeTrip;
      if (activeTrip != null) {
        trips.removeWhere((t) => t.id == activeTrip.id);
        trips.add(activeTrip.copyWith(
          routePoints: trackingEngine.activeRoutePoints,
          distanceMeters: trackingEngine.activeTripDistance,
        ));
      }
    }

    // Sort visits and trips chronologically
    visits.sort((a, b) => a.startTime.compareTo(b.startTime));
    trips.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Interleave into a unified day timeline
    final events = <DayTimelineEvent>[];
    int stopCounter = 1;
    for (final v in visits) {
      events.add(DayTimelineVisit(
        visit: v,
        place: pMap[v.placeId],
        stopNumber: stopCounter++,
      ));
    }
    for (final t in trips) {
      events.add(DayTimelineTrip(t));
    }
    events.sort((a, b) => a.time.compareTo(b.time));

    // Compute day totals
    double distSum = 0.0;
    int movingSec = 0;
    for (final t in trips) {
      distSum += t.distanceMeters;
      movingSec += t.durationSeconds;
    }

    int statSec = 0;
    for (final v in visits) {
      statSec += v.currentDuration.inSeconds;
    }

    dynamic initialSelect;
    if (widget.initialTripId != null) {
      for (final t in trips) {
        if (t.id == widget.initialTripId) {
          initialSelect = t;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _visits = visits;
      _trips = trips;
      _placeMap = pMap;
      _timelineEvents = events;
      _totalDistanceMeters = distSum;
      _totalMovingDurationSeconds = movingSec;
      _totalStationaryDurationSeconds = statSec;
      if (!silent || _selectedItem == null) {
        _selectedItem = initialSelect;
      } else if (_selectedItem != null) {
        if (_selectedItem is Trip) {
          final updated = trips.where((t) => t.id == (_selectedItem as Trip).id).firstOrNull;
          if (updated != null) _selectedItem = updated;
        } else if (_selectedItem is VisitSession) {
          final updated = visits.where((v) => v.id == (_selectedItem as VisitSession).id).firstOrNull;
          if (updated != null) _selectedItem = updated;
        }
      }
      _isLoading = false;
    });

    if (!silent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (initialSelect != null && initialSelect is Trip) {
          _focusTrip(initialSelect);
        } else {
          _fitWholeDay();
        }
      });
    }
  }

  void _previousDay() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _selectedItem = null;
    });
    _loadDayData();
  }

  void _nextDay() {
    if (_isToday) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _selectedItem = null;
    });
    _loadDayData();
  }

  void _jumpToToday() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedItem = null;
    });
    _loadDayData();
  }

  Future<void> _pickCustomDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _selectedItem = null;
      });
      _loadDayData();
    }
  }

  void _smoothMove(LatLng destLocation, double destZoom) {
    try {
      _cameraAnimController?.dispose();
      final controller = AnimationController(
        duration: const Duration(milliseconds: 650),
        vsync: this,
      );
      _cameraAnimController = controller;

      final startLat = _mapController.camera.center.latitude;
      final startLng = _mapController.camera.center.longitude;
      final startZoom = _mapController.camera.zoom;

      final latTween = Tween<double>(begin: startLat, end: destLocation.latitude);
      final lngTween = Tween<double>(begin: startLng, end: destLocation.longitude);
      final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

      final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

      controller.addListener(() {
        _mapController.move(
          LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
          zoomTween.evaluate(curve),
        );
      });

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          controller.dispose();
          if (_cameraAnimController == controller) {
            _cameraAnimController = null;
          }
        }
      });

      controller.forward();
    } catch (_) {
      try {
        _mapController.move(destLocation, destZoom);
      } catch (_) {}
    }
  }

  void _fitWholeDay() {
    final allPoints = <LatLng>[];

    // Collect all trip points
    for (final t in _trips) {
      allPoints.addAll(t.latLngPoints);
    }

    // Collect all place locations visited today
    for (final v in _visits) {
      final p = _placeMap[v.placeId];
      if (p != null) {
        allPoints.add(LatLng(p.latitude, p.longitude));
      }
    }

    if (allPoints.isEmpty) {
      // Default to user place or Rome
      if (_placeMap.isNotEmpty) {
        final first = _placeMap.values.first;
        _smoothMove(LatLng(first.latitude, first.longitude), 14.0);
      } else {
        _smoothMove(const LatLng(41.9028, 12.4964), 12.0);
      }
      return;
    }

    if (allPoints.length == 1) {
      _smoothMove(allPoints.first, 15.5);
      return;
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    final dLat = maxLat - minLat;
    final dLng = maxLng - minLng;
    final maxSpan = max(dLat, dLng);

    double zoom = 14.0;
    if (maxSpan > 1.2) {
      zoom = 8.5;
    } else if (maxSpan > 0.5) {
      zoom = 10.0;
    } else if (maxSpan > 0.2) {
      zoom = 11.5;
    } else if (maxSpan > 0.08) {
      zoom = 12.8;
    } else if (maxSpan > 0.03) {
      zoom = 13.8;
    } else if (maxSpan > 0.01) {
      zoom = 14.8;
    } else {
      zoom = 15.5;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _smoothMove(center, zoom);
  }

  void _focusTrip(Trip trip) {
    setState(() => _selectedItem = trip);
    final pts = trip.latLngPoints;
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      _smoothMove(pts.first, 16.0);
      return;
    }

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    final maxSpan = max(maxLat - minLat, maxLng - minLng);
    double zoom = 14.5;
    if (maxSpan > 0.8) {
      zoom = 9.5;
    } else if (maxSpan > 0.3) {
      zoom = 11.0;
    } else if (maxSpan > 0.1) {
      zoom = 12.5;
    } else if (maxSpan > 0.04) {
      zoom = 13.8;
    } else if (maxSpan > 0.01) {
      zoom = 14.8;
    } else {
      zoom = 15.8;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _smoothMove(center, zoom);
  }

  void _focusVisit(VisitSession visit, Place? place) {
    setState(() => _selectedItem = visit);
    if (place != null) {
      _smoothMove(LatLng(place.latitude, place.longitude), 16.5);
    }
  }

  Future<void> _editTripMode(Trip trip) async {
    HapticFeedback.selectionClick();
    final newMode = await TransportModePicker.show(context, currentMode: trip.transportMode);
    if (newMode != null && newMode != trip.transportMode && mounted) {
      final engine = Provider.of<TrackingEngine>(context, listen: false);
      await engine.updateTripTransportMode(trip, newMode);
      await _loadDayData();
    }
  }

  @override
  void dispose() {
    try {
      Provider.of<TrackingEngine>(context, listen: false).removeListener(_onTrackingEngineUpdated);
    } catch (_) {}
    _cameraAnimController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final dateTitle = _isToday
        ? 'Oggi, ${DateFormat('d MMMM', 'it_IT').format(_selectedDate)}'
        : DateFormat('EEEE d MMMM yyyy', 'it_IT').format(_selectedDate);

    // Format totals
    final kmStr = (_totalDistanceMeters / 1000).toStringAsFixed(1);
    final moveHours = _totalMovingDurationSeconds ~/ 3600;
    final moveMins = (_totalMovingDurationSeconds % 3600) ~/ 60;
    final moveTimeStr = moveHours > 0 ? '${moveHours}h ${moveMins}m' : '${moveMins}m';

    final stayHours = _totalStationaryDurationSeconds ~/ 3600;
    final stayMins = (_totalStationaryDurationSeconds % 3600) ~/ 60;
    final stayTimeStr = stayHours > 0 ? '${stayHours}h ${stayMins}m' : '${stayMins}m';

    // Build polylines
    final polylines = <Polyline>[];
    for (final trip in _trips) {
      if (trip.routePoints.length >= 2) {
        final isSelected = _selectedItem == trip;
        final tripColor = TransportMode.getColor(trip.transportMode);
        polylines.add(
          Polyline(
            points: trip.latLngPoints,
            color: isSelected
                ? tripColor
                : (_selectedItem != null ? tripColor.withValues(alpha: 0.3) : tripColor),
            strokeWidth: isSelected ? 6.5 : 4.5,
            borderColor: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
            borderStrokeWidth: isSelected ? 2.5 : 1.5,
          ),
        );
      }
    }

    // Build markers
    final markers = <Marker>[];
    int stopNumber = 1;
    for (final visit in _visits) {
      final place = _placeMap[visit.placeId];
      if (place != null) {
        final isSelected = _selectedItem == visit;
        final currentStopNum = stopNumber++;
        markers.add(
          Marker(
            point: LatLng(place.latitude, place.longitude),
            width: isSelected ? 64 : 50,
            height: isSelected ? 64 : 50,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _focusVisit(visit, place);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isSelected ? 56 : 42,
                    height: isSelected ? 56 : 42,
                    decoration: BoxDecoration(
                      color: place.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                      boxShadow: [
                        BoxShadow(
                          color: place.color.withValues(alpha: 0.45),
                          blurRadius: isSelected ? 14 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      place.icon,
                      color: Colors.white,
                      size: isSelected ? 24 : 18,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$currentStopNum',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Interactive Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(45.4642, 9.1900),
                initialZoom: 13.0,
                onTap: (_, __) {
                  if (_selectedItem != null) {
                    setState(() => _selectedItem = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tempo.app.tempo',
                  maxZoom: 20,
                  maxNativeZoom: 19,
                  tileBuilder: isDark ? darkModeTileBuilder : null,
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // 2. Google Maps Timeline Top Date Navigator Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Back button
                    FloatingActionButton.small(
                      heroTag: 'timeline_back',
                      backgroundColor: cardBg,
                      foregroundColor: textPrimary,
                      elevation: 4,
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),

                    // Date Navigator Capsule (Google Maps style)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg.withValues(alpha: isDark ? 0.95 : 0.98),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 24),
                              tooltip: 'Giorno precedente',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: _previousDay,
                            ),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _pickCustomDate,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          dateTitle,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.chevron_right_rounded,
                                size: 24,
                                color: _isToday ? textMuted.withValues(alpha: 0.3) : textPrimary,
                              ),
                              tooltip: 'Giorno successivo',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: _isToday ? null : _nextDay,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!_isToday) ...[
                      const SizedBox(width: 8),
                      // "Oggi" shortcut button
                      FloatingActionButton.small(
                        heroTag: 'timeline_today_shortcut',
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        tooltip: 'Torna ad oggi',
                        onPressed: _jumpToToday,
                        child: const Text('Oggi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Map Action Buttons (Inquadra giornata, Zoom)
          Positioned(
            right: 16,
            top: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Inquadra tutta la giornata (Overview)
                FloatingActionButton.small(
                  heroTag: 'timeline_fit_day',
                  backgroundColor: cardBg,
                  foregroundColor: const Color(0xFF0EA5E9),
                  elevation: 4,
                  tooltip: 'Inquadra l\'intera giornata',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _fitWholeDay();
                  },
                  child: const Icon(Icons.crop_free_rounded),
                ),
                const SizedBox(height: 10),
                // Zoom in
                FloatingActionButton.small(
                  heroTag: 'timeline_zoom_in',
                  backgroundColor: cardBg,
                  foregroundColor: textPrimary,
                  elevation: 4,
                  tooltip: 'Ingrandisci',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, (zoom + 1).clamp(1.0, 20.0));
                  },
                  child: const Icon(Icons.add_rounded),
                ),
                const SizedBox(height: 6),
                // Zoom out
                FloatingActionButton.small(
                  heroTag: 'timeline_zoom_out',
                  backgroundColor: cardBg,
                  foregroundColor: textPrimary,
                  elevation: 4,
                  tooltip: 'Rimpicciolisci',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, (zoom - 1).clamp(1.0, 20.0));
                  },
                  child: const Icon(Icons.remove_rounded),
                ),
              ],
            ),
          ),

          // 4. Draggable Timeline Bottom Sheet ("in elenco", stile Google Maps)
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.22,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.22, 0.44, 0.88],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                      blurRadius: 28,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Sheet Drag Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 10),
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Day Summary Stats Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'La mia giornata',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_trips.length} spostamenti • ${_visits.length} soste',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0EA5E9),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _fitWholeDay,
                                icon: const Icon(Icons.map_rounded, size: 16),
                                label: const Text('Inquadra tutto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Three Summary Pills
                          Row(
                            children: [
                              _buildStatBadge(
                                icon: Icons.route_rounded,
                                color: const Color(0xFF0EA5E9),
                                label: '$kmStr km',
                                subtitle: 'Distanza',
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildStatBadge(
                                icon: Icons.directions_walk_rounded,
                                color: const Color(0xFF10B981),
                                label: moveTimeStr,
                                subtitle: 'In viaggio',
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildStatBadge(
                                icon: Icons.home_work_rounded,
                                color: const Color(0xFF8B5CF6),
                                label: stayTimeStr,
                                subtitle: 'Nei luoghi',
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, thickness: 1, color: borderColor),

                    // Timeline Content / List of Events
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_timelineEvents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.explore_off_rounded, size: 40, color: textMuted),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Nessun tragitto o sosta registrata',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isToday
                                  ? 'Non hai ancora effettuato spostamenti oggi. Quando ti muovi, Tempo traccerà automaticamente il percorso sulla mappa!'
                                  : 'Non ci sono dati salvati per questa data nel tuo archivio.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
                            ),
                            if (!_isToday) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _jumpToToday,
                                icon: const Icon(Icons.today_rounded, size: 16),
                                label: const Text('Vai alla giornata di oggi'),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            for (int i = 0; i < _timelineEvents.length; i++)
                              _buildTimelineItem(
                                _timelineEvents[i],
                                isLast: i == _timelineEvents.length - 1,
                                isDark: isDark,
                                textPrimary: textPrimary,
                                textMuted: textMuted,
                                borderColor: borderColor,
                                elevatedBg: elevatedBg,
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    DayTimelineEvent event, {
    required bool isLast,
    required bool isDark,
    required Color textPrimary,
    required Color textMuted,
    required Color borderColor,
    required Color elevatedBg,
  }) {
    final timeFormat = DateFormat('HH:mm');

    if (event is DayTimelineVisit) {
      final v = event.visit;
      final p = event.place;
      final isSelected = _selectedItem == v;
      final placeColor = p?.color ?? v.category.defaultColor;
      final placeIcon = p?.icon ?? v.category.icon;
      final startStr = timeFormat.format(v.startTime);
      final endStr = v.endTime != null ? timeFormat.format(v.endTime!) : 'In corso';

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Spine (Marker + Vertical Line)
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: placeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 2),
                      boxShadow: [
                        BoxShadow(
                          color: placeColor.withValues(alpha: 0.4),
                          blurRadius: isSelected ? 10 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${event.stopNumber}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.5,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _focusVisit(v, p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? placeColor.withValues(alpha: isDark ? 0.2 : 0.1)
                          : elevatedBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? placeColor : borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: placeColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(placeIcon, size: 16, color: placeColor),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v.placeName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? placeColor : textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: placeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                v.formattedDuration,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: placeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '$startStr - $endStr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                            if (v.isOngoing) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Ora qui',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (event is DayTimelineTrip) {
      final t = event.trip;
      final isSelected = _selectedItem == t;
      final tripColor = TransportMode.getColor(t.transportMode);
      final tripIcon = TransportMode.getIcon(t.transportMode);
      final startStr = timeFormat.format(t.startTime);
      final endStr = t.endTime != null ? timeFormat.format(t.endTime!) : 'In corso';

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Spine (Vehicle Icon + Vertical Line)
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tripColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: tripColor, width: 1.5),
                    ),
                    child: Icon(tripIcon, size: 16, color: tripColor),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.5,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Trip Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _focusTrip(t);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tripColor.withValues(alpha: isDark ? 0.2 : 0.1)
                          : elevatedBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? tripColor : borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${t.originPlaceName} ➔ ${t.destinationPlaceName ?? "In corso"}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? tripColor : textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _editTripMode(t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tripColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      t.transportMode,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: tripColor,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(Icons.edit_rounded, size: 10, color: tripColor),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '$startStr - $endStr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•  ${t.formattedDistance}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: tripColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '•  ${t.formattedDuration}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                            if (t.averageSpeedKmH > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '•  ${t.averageSpeedKmH.toStringAsFixed(0)} km/h',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
