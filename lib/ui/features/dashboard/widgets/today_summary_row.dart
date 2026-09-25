import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class TodaySummaryRow extends StatelessWidget {
  final String formattedTotal;
  final String? topPlace;
  final int visitCount;

  const TodaySummaryRow({
    super.key,
    required this.formattedTotal,
    required this.topPlace,
    required this.visitCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'TEMPO OGGI',
            value: formattedTotal,
            subtitle: '$visitCount sessioni',
            icon: Icons.hourglass_top_rounded,
            iconColor: AppColors.primaryLight,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            title: 'LUOGO TOP',
            value: topPlace ?? 'Nessuno',
            subtitle: topPlace != null ? 'Più frequentato' : 'In attesa',
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
