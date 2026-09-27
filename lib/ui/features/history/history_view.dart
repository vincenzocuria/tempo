import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/visit_session.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../places/places_view_model.dart';
import '../trips/transport_mode_picker.dart';
import 'manual_visit_dialog.dart';

enum HistoryFilter { tutto, soste, tragitti }

abstract class HistoryItem {
  String get id;
  DateTime get time;
}

class HistoryVisitItem extends HistoryItem {
  final VisitSession visit;
  HistoryVisitItem(this.visit);
  @override
  String get id => visit.id;
  @override
  DateTime get time => visit.startTime;
}

class HistoryTripItem extends HistoryItem {
  final Trip trip;
  HistoryTripItem(this.trip);
  @override
  String get id => trip.id;
  @override
  DateTime get time => trip.startTime;
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<VisitSession> _visits = [];
  List<Trip> _trips = [];
  bool _isLoading = true;
  String _searchQuery = '';
  HistoryFilter _filter = HistoryFilter.tutto;

  PlacesViewModel? _placesVm;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newVm = Provider.of<PlacesViewModel>(context);
    if (_placesVm != newVm) {
      _placesVm?.removeListener(_onPlacesChanged);
      _placesVm = newVm;
      _placesVm?.addListener(_onPlacesChanged);
    }
  }

  void _onPlacesChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _placesVm?.removeListener(_onPlacesChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);
    final tripRepo = Provider.of<TripRepository>(context, listen: false);

    final v = await visitRepo.getVisits();
    final t = await tripRepo.getTrips();

    if (!mounted) return;
    setState(() {
      _visits = v;
      _trips = t;
      _isLoading = false;
    });
  }

  void _deleteVisit(String id) async {
    final repo = Provider.of<VisitRepository>(context, listen: false);
    await repo.deleteVisit(id);
    if (!mounted) return;
    _loadData();
  }

  void _deleteTrip(String id) async {
    final repo = Provider.of<TripRepository>(context, listen: false);
    await repo.deleteTrip(id);
    if (!mounted) return;
    _loadData();
  }

  void _showTripRouteModal(Trip trip) {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final tripColor = TransportMode.getColor(trip.transportMode);
    final tripIcon = TransportMode.getIcon(trip.transportMode);

    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(trip.startTime);
    final endStr = trip.endTime != null ? timeFormat.format(trip.endTime!) : 'In corso';
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'it_IT').format(trip.startTime);

    final points = trip.latLngPoints;

    LatLng center = const LatLng(41.9028, 12.4964);
    double zoom = 14.0;

    if (points.isNotEmpty) {
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

      center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      final maxSpan = max(maxLat - minLat, maxLng - minLng);
      if (maxSpan > 1.0) {
        zoom = 8.5;
      } else if (maxSpan > 0.4) {
        zoom = 10.0;
      } else if (maxSpan > 0.15) {
        zoom = 11.5;
      } else if (maxSpan > 0.05) {
        zoom = 13.0;
      } else if (maxSpan > 0.02) {
        zoom = 14.2;
      } else {
        zoom = 15.2;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tripColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tripIcon, color: tripColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.originPlaceName} ➔ ${trip.destinationPlaceName ?? "In corso"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$dateStr • $startStr - $endStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Distanza', style: TextStyle(fontSize: 11, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(trip.formattedDistance, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: borderColor),
                    Column(
                      children: [
                        Text('Durata', style: TextStyle(fontSize: 11, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(trip.formattedDuration, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: borderColor),
                    Column(
                      children: [
                        Text('Velocità Media', style: TextStyle(fontSize: 11, color: textMuted)),
                        const SizedBox(height: 2),
                        Text('${trip.averageSpeedKmH.toStringAsFixed(1)} km/h', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Map Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: points.length >= 2
                      ? FlutterMap(
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: zoom,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.tempo.app.tempo',
                              maxZoom: 19,
                              tileBuilder: isDark ? darkModeTileBuilder : null,
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: points,
                                  color: tripColor,
                                  strokeWidth: 5.5,
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 2.0,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: points.first,
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.trip_origin_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                                Marker(
                                  point: points.last,
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Container(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_off_rounded, size: 36, color: textMuted),
                              const SizedBox(height: 8),
                              Text('Nessun punto GPS registrato per questo tragitto', style: TextStyle(color: textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: borderColor),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final newMode = await TransportModePicker.show(
                          context,
                          currentMode: trip.transportMode,
                        );
                        if (newMode != null && newMode != trip.transportMode && mounted) {
                          final engine = Provider.of<TrackingEngine>(context, listen: false);
                          await engine.updateTripTransportMode(trip, newMode);
                          _loadData();
                        }
                      },
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: Text('Cambia Mezzo (${trip.transportMode})'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tripColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Chiudi', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatItalianDayHeader(DateTime dt) {
    try {
      final fullFormat = DateFormat('EEEE d MMMM yyyy', 'it_IT');
      final s = fullFormat.format(dt);
      return s[0].toUpperCase() + s.substring(1);
    } catch (_) {
      const days = [
        'Lunedì',
        'Martedì',
        'Mercoledì',
        'Giovedì',
        'Venerdì',
        'Sabato',
        'Domenica'
      ];
      const months = [
        'Gennaio',
        'Febbraio',
        'Marzo',
        'Aprile',
        'Maggio',
        'Giugno',
        'Luglio',
        'Agosto',
        'Settembre',
        'Ottobre',
        'Novembre',
        'Dicembre'
      ];
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
  }

  Map<String, List<HistoryItem>> _groupItemsByDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final List<HistoryItem> items = [];

    if (_filter == HistoryFilter.tutto || _filter == HistoryFilter.soste) {
      for (final v in _visits) {
        if (_searchQuery.isNotEmpty &&
            !v.placeName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !v.category.displayName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        items.add(HistoryVisitItem(v));
      }
    }

    if (_filter == HistoryFilter.tutto || _filter == HistoryFilter.tragitti) {
      for (final t in _trips) {
        if (_searchQuery.isNotEmpty &&
            !t.originPlaceName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !(t.destinationPlaceName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) &&
            !t.transportMode.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        items.add(HistoryTripItem(t));
      }
    }

    // Sort items chronologically descending
    items.sort((a, b) => b.time.compareTo(a.time));

    final groups = <String, List<HistoryItem>>{};

    for (final item in items) {
      final dateOnly = DateTime(item.time.year, item.time.month, item.time.day);
      String key;
      if (dateOnly == today) {
        key = 'Oggi';
      } else if (dateOnly == yesterday) {
        key = 'Ieri';
      } else {
        key = _formatItalianDayHeader(dateOnly);
      }

      groups.putIfAbsent(key, () => []).add(item);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final timeFormat = DateFormat('HH:mm');
    final grouped = _groupItemsByDay();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronologia'),
        actions: [
          IconButton(
            tooltip: 'Aggiungi visita manuale',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => ManualVisitDialog.show(context, onVisitAdded: _loadData),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (Tutto, Soste, Tragitti)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                _buildFilterChip('Tutto', HistoryFilter.tutto, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Soste (${_visits.length})', HistoryFilter.soste, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Tragitti (${_trips.length})', HistoryFilter.tragitti, isDark),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Cerca per nome, destinazione o categoria...',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // List or Empty View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 56,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nessuna attività trovata',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Nessun risultato corrisponde alla ricerca.'
                                    : 'Le visite e i tragitti completati verranno archiviati qui in ordine cronologico.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final dayKey = grouped.keys.elementAt(index);
                            final dayItems = grouped[dayKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    dayKey,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ),
                                ),
                                ...dayItems.map((item) {
                                  if (item is HistoryVisitItem) {
                                    final v = item.visit;
                                    final startStr = timeFormat.format(v.startTime);
                                    final endStr = v.endTime != null
                                        ? timeFormat.format(v.endTime!)
                                        : 'In corso';

                                    return Dismissible(
                                      key: Key('visit_${v.id}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                                      ),
                                      onDismissed: (_) => _deleteVisit(v.id),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: borderColor),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: v.category.defaultColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                v.category.icon,
                                                color: v.category.defaultColor,
                                                size: 22,
                                              ),
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
                                                          v.placeName,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w700,
                                                            color: textPrimary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (v.isManual) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'Manuale',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w700,
                                                              color: textMuted,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$startStr - $endStr',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: textMuted,
                                                    ),
                                                  ),
                                                  if (v.notes != null && v.notes!.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      v.notes!,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontStyle: FontStyle.italic,
                                                        color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: v.isOngoing
                                                    ? AppColors.primary.withValues(alpha: 0.15)
                                                    : elevatedBg,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                v.formattedDuration,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: v.isOngoing
                                                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                                      : textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else if (item is HistoryTripItem) {
                                    final t = item.trip;
                                    final startStr = timeFormat.format(t.startTime);
                                    final endStr = t.endTime != null
                                        ? timeFormat.format(t.endTime!)
                                        : 'In corso';

                                    final tripAccent = TransportMode.getColor(t.transportMode);
                                    final tripIcon = TransportMode.getIcon(t.transportMode);

                                    return Dismissible(
                                      key: Key('trip_${t.id}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                                      ),
                                      onDismissed: (_) => _deleteTrip(t.id),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        decoration: BoxDecoration(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark ? AppColors.darkBorder : tripAccent.withValues(alpha: 0.35),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () => _showTripRouteModal(t),
                                            onLongPress: () async {
                                              HapticFeedback.selectionClick();
                                              final newMode = await TransportModePicker.show(
                                                context,
                                                currentMode: t.transportMode,
                                              );
                                              if (newMode != null && newMode != t.transportMode && context.mounted) {
                                                final engine = Provider.of<TrackingEngine>(context, listen: false);
                                                await engine.updateTripTransportMode(t, newMode);
                                                _loadData();
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: tripAccent.withValues(alpha: 0.14),
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    child: Icon(
                                                      tripIcon,
                                                      color: tripAccent,
                                                      size: 22,
                                                    ),
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
                                                                '${t.originPlaceName} ➔ ${t.destinationPlaceName ?? "In corso"}',
                                                                style: TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: textPrimary,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              '$startStr - $endStr • ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w500,
                                                                color: textMuted,
                                                              ),
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: tripAccent.withValues(alpha: 0.12),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(
                                                                    t.transportMode,
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.w800,
                                                                      color: tripAccent,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 3),
                                                                  Icon(Icons.edit_rounded, size: 9, color: tripAccent),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: tripAccent.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          t.formattedDistance,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w800,
                                                            color: tripAccent,
                                                          ),
                                                        ),
                                                        Text(
                                                          t.formattedDuration,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: textMuted,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, HistoryFilter filterValue, bool isDark) {
    final isSelected = _filter == filterValue;
    return InkWell(
      onTap: () => setState(() => _filter = filterValue),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
          ),
        ),
      ),
    );
  }
}
