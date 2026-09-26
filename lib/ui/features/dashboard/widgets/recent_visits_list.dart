import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/visit_session.dart';
import '../../../core/app_colors.dart';

abstract class TimelineItem {
  DateTime get time;
}

class VisitTimelineItem extends TimelineItem {
  final VisitSession visit;
  VisitTimelineItem(this.visit);
  @override
  DateTime get time => visit.startTime;
}

class TripTimelineItem extends TimelineItem {
  final Trip trip;
  TripTimelineItem(this.trip);
  @override
  DateTime get time => trip.startTime;
}

class RecentVisitsList extends StatelessWidget {
  final List<VisitSession> visits;
  final List<Trip> trips;
  final VoidCallback onViewAllTap;

  const RecentVisitsList({
    super.key,
    required this.visits,
    this.trips = const [],
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm');

    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

    // Combine visits and trips into a single sorted chronological list
    final List<TimelineItem> items = [
      ...visits.map((v) => VisitTimelineItem(v)),
      ...trips.map((t) => TripTimelineItem(t)),
    ]..sort((a, b) => b.time.compareTo(a.time));

    final displayItems = items.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Attività di Oggi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            if (displayItems.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: onViewAllTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text(
                  'Cronologia',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (displayItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    size: 28,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nessuna attività oggi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'I tuoi spostamenti e soste verranno mostrati qui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = displayItems[index];

              if (item is VisitTimelineItem) {
                final visit = item.visit;
                final category = visit.category;
                final startStr = timeFormat.format(visit.startTime);
                final endStr = visit.endTime != null
                    ? timeFormat.format(visit.endTime!)
                    : 'In corso';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: visit.isOngoing
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : borderColor,
                      width: visit.isOngoing ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: category.defaultColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: category.defaultColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.defaultColor,
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
                                    visit.placeName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (visit.isOngoing) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ORA',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$startStr – $endStr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: visit.isOngoing
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : elevatedBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: visit.isOngoing
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          visit.formattedDuration,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: visit.isOngoing
                                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                : textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (item is TripTimelineItem) {
                final trip = item.trip;
                final startStr = timeFormat.format(trip.startTime);
                final endStr = trip.endTime != null
                    ? timeFormat.format(trip.endTime!)
                    : 'In corso';

                const tripAccent = Color(0xFF0EA5E9);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: trip.isOngoing
                          ? tripAccent.withValues(alpha: 0.6)
                          : borderColor,
                      width: trip.isOngoing ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tripAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: tripAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
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
                                    '${trip.originPlaceName} ➔ ${trip.destinationPlaceName ?? 'In corso'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (trip.isOngoing) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tripAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'VIAGGIO',
                                      style: TextStyle(
                                        color: tripAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$startStr – $endStr • ${trip.transportMode}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tripAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              trip.formattedDistance,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: tripAccent,
                              ),
                            ),
                            Text(
                              trip.formattedDuration,
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
