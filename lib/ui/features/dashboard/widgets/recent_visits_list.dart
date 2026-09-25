import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/visit_session.dart';
import '../../../core/app_colors.dart';

class RecentVisitsList extends StatelessWidget {
  final List<VisitSession> visits;
  final VoidCallback onViewAllTap;

  const RecentVisitsList({
    super.key,
    required this.visits,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ultime Visite di Oggi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: onViewAllTap,
              child: const Text('Vedi tutte'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visits.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 40,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nessuna visita registrata oggi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le tue soste a lavoro o palestra appariranno qui automaticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visits.length > 5 ? 5 : visits.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final visit = visits[index];
              final category = visit.category;
              final startStr = timeFormat.format(visit.startTime);
              final endStr = visit.endTime != null
                  ? timeFormat.format(visit.endTime!)
                  : 'In corso';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: category.defaultColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
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
                          Text(
                            visit.placeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$startStr - $endStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                            ? AppColors.primary.withOpacity(0.15)
                            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        visit.formattedDuration,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: visit.isOngoing
                              ? AppColors.primaryLight
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
