import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/place.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/services/tracking_engine.dart';
import '../../../core/app_colors.dart';
import '../../places/place_form_dialog.dart';
import '../../places/places_view_model.dart';
import '../../trips/transport_mode_picker.dart';

class LiveStatusCard extends StatefulWidget {
  final TrackingEngine trackingEngine;
  final VoidCallback onQuickCheckInTap;

  const LiveStatusCard({
    super.key,
    required this.trackingEngine,
    required this.onQuickCheckInTap,
  });

  @override
  State<LiveStatusCard> createState() => _LiveStatusCardState();
}

class _LiveStatusCardState extends State<LiveStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.trackingEngine;
    final activeVisit = engine.activeVisit;
    final currentPlace = engine.currentPlace;
    final isInside = activeVisit != null && currentPlace != null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary = isDark
        ? AppColors.textDarkPrimary
        : AppColors.textLightPrimary;
    final textMuted = isDark
        ? AppColors.textDarkMuted
        : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final timeFormatter = DateFormat('HH:mm');

    // -------------------------------------------------------------
    // STATE 1: ACTIVE VISIT (IN SOSTA) - Ultra-Clean Executive Hero
    // -------------------------------------------------------------
    if (isInside) {
      final placeColor = currentPlace.color;

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: placeColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: placeColor.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Bar: Live Breathing Dot + Category Tag + Arrival Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: placeColor.withValues(
                              alpha: _pulseAnimation.value,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: placeColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'IN SOSTA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: placeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: placeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentPlace.category.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: placeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Dalle ${timeFormatter.format(activeVisit.startTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Middle Row: Place Icon + Place Name + Dynamic Timer
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: placeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(currentPlace.icon, color: placeColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPlace.name,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeVisit.isManual
                            ? 'Check-in manuale'
                            : 'Rilevamento automatico GPS',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Bottom Section: Clean Tabular Figures Timer & Termina Sosta Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEMPO TRASCORSO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(activeVisit.currentDuration),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: 0.5,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      engine.manualCheckOut();
                    },
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text(
                      'Termina',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // STATE 2: ACTIVE TRIP (IN SPOSTAMENTO / TRAGITTO IN CORSO)
    // -------------------------------------------------------------
    final activeTrip = engine.activeTrip;
    if (activeTrip != null) {
      const tripColor = Color(0xFF0EA5E9); // Bright Cyan / Sky Blue

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: tripColor.withValues(alpha: isDark ? 0.4 : 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: tripColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Bar: Live Moving Indicator + Mode Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tripColor.withValues(
                              alpha: _pulseAnimation.value,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tripColor.withValues(alpha: 0.6),
                                blurRadius: 8 * _pulseAnimation.value,
                                spreadRadius: 2 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TransportMode.getColor(activeTrip.transportMode)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            TransportMode.getIcon(activeTrip.transportMode),
                            size: 14,
                            color: TransportMode.getColor(
                              activeTrip.transportMode,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'IN SPOSTAMENTO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: TransportMode.getColor(
                                activeTrip.transportMode,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final newMode = await TransportModePicker.show(
                      context,
                      currentMode: activeTrip.transportMode,
                    );
                    if (newMode != null &&
                        newMode != activeTrip.transportMode) {
                      engine.updateActiveTripMode(newMode);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeTrip.transportMode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TransportMode.getColor(
                              activeTrip.transportMode,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_rounded,
                          size: 11,
                          color: TransportMode.getColor(
                            activeTrip.transportMode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Middle: Origin & Live Distance
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  activeTrip.formattedDistance,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'percorsi da ${activeTrip.originPlaceName}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bottom Section: Tabular Figures Timer & Complete Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : const Color(0xFFBAE6FD),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEMPO IN VIAGGIO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(activeTrip.currentDuration),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: 0.5,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: tripColor.withValues(alpha: 0.12),
                          foregroundColor: tripColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          engine.manualFinishTrip();
                        },
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Termina',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onQuickCheckInTap();
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_rounded, size: 15),
                            SizedBox(width: 2),
                            Text(
                              'Arrivo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // STATE 3: OUTSIDE IDLE (FUORI DAI LUOGHI NOTI) - Executive Hero Card
    // -------------------------------------------------------------
    final placesVm = Provider.of<PlacesViewModel>(context);
    final places = placesVm.places;
    final pos = engine.lastKnownPosition;

    Place? nearestPlace;
    double minDistance = double.infinity;
    if (pos != null && places.isNotEmpty) {
      for (final p in places) {
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          p.latitude,
          p.longitude,
        );
        if (d < minDistance) {
          minDistance = d;
          nearestPlace = p;
        }
      }
    }

    String? distanceText;
    if (nearestPlace != null && minDistance < double.infinity) {
      if (minDistance < 1000) {
        distanceText = '${minDistance.round()} m da ${nearestPlace.name}';
      } else {
        distanceText =
            '${(minDistance / 1000).toStringAsFixed(1)} km da ${nearestPlace.name}';
      }
    }

    const outsideColor = Color(0xFFF59E0B); // Amber / Warm Accent

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: outsideColor.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: outsideColor.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Bar: Radar Breathing Dot + Badge + GPS Live Telemetry
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: outsideColor.withValues(
                            alpha: _pulseAnimation.value,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: outsideColor.withValues(alpha: 0.6),
                              blurRadius: 8 * _pulseAnimation.value,
                              spreadRadius: 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: outsideColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'FUORI DAI LUOGHI NOTI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: outsideColor,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: engine.isChecking
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        engine.checkCurrentLocation();
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (engine.isChecking) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rilevo...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.refresh_rounded, size: 14, color: textMuted),
                        const SizedBox(width: 4),
                        Text(
                          pos != null
                              ? '±${pos.accuracy.round()}m'
                              : 'Rileva GPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Middle: Icon + Title + Nearest Place / Status Message
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: outsideColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: outsideColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posizione Attuale',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (distanceText != null)
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'A $distanceText',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        engine.statusMessage ??
                            'In attesa di raggiungere un luogo registrato',
                        style: TextStyle(fontSize: 12, color: textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Coordinates & Speed telemetry strip
          if (pos != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: textPrimary,
                      ),
                    ),
                  ),
                  if (pos.speed > 0.8)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.speed_rounded,
                            size: 12,
                            color: Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(pos.speed * 3.6).round()} km/h',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Action Buttons: Salva Luogo + Avvia Tragitto + Check-in
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: outsideColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  final latLng = pos != null
                      ? LatLng(pos.latitude, pos.longitude)
                      : null;
                  PlaceFormDialog.show(context, initialLocation: latLng);
                },
                icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                label: const Text(
                  'Salva Luogo',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  final origin = nearestPlace != null
                      ? 'Nei pressi di ${nearestPlace.name}'
                      : 'Posizione corrente';
                  engine.startManualTrip(originName: origin);
                },
                icon: const Icon(Icons.directions_car_rounded, size: 16),
                label: const Text(
                  'Avvia Tragitto',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onQuickCheckInTap();
                },
                icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                label: const Text(
                  'Check-in',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
