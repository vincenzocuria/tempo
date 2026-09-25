import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place_category.dart';
import '../../core/app_colors.dart';
import 'analytics_view_model.dart';

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalyticsViewModel>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche & Ore'),
      ),
      body: RefreshIndicator(
        onRefresh: () => viewModel.loadAnalytics(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AnalyticsTimeFilter.values.map((f) {
                  final isSelected = viewModel.selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(f.displayName),
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : borderColor,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : textPrimary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                      onSelected: (_) => viewModel.setFilter(f),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Top Spotlight Cards (Lavoro & Palestra focus)
            Row(
              children: [
                Expanded(
                  child: _HeroMetricCard(
                    title: 'ORE A LAVORO',
                    value: viewModel.formatSeconds(viewModel.workSeconds),
                    icon: Icons.business_center_rounded,
                    accentColor: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _HeroMetricCard(
                    title: 'ORE IN PALESTRA',
                    value: viewModel.formatSeconds(viewModel.gymSeconds),
                    icon: Icons.fitness_center_rounded,
                    accentColor: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (viewModel.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (viewModel.totalDurationSeconds == 0)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'Nessun dato per questo intervallo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'I dati compariranno automaticamente man mano che visiti i tuoi luoghi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Pie Chart: Distribution by Category
              _CategoryPieChartSection(
                categoryDurations: viewModel.durationByCategory,
                totalSeconds: viewModel.totalDurationSeconds,
                formatDuration: viewModel.formatSeconds,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Bar Chart: Daily Trend
              _DailyBarChartSection(
                dailyDurations: viewModel.dailyDurations,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Top Places Ranking List
              _PlacesRankingSection(
                placesDuration: viewModel.durationByPlace,
                totalSeconds: viewModel.totalDurationSeconds,
                formatDuration: viewModel.formatSeconds,
                isDark: isDark,
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isDark;

  const _HeroMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
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
                  color: textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieChartSection extends StatelessWidget {
  final Map<PlaceCategory, int> categoryDurations;
  final int totalSeconds;
  final String Function(int) formatDuration;
  final bool isDark;

  const _CategoryPieChartSection({
    required this.categoryDurations,
    required this.totalSeconds,
    required this.formatDuration,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final sections = categoryDurations.entries.map((entry) {
      final cat = entry.key;
      final sec = entry.value;

      return PieChartSectionData(
        value: sec.toDouble(),
        title: '',
        color: cat.defaultColor,
        radius: 20,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribuzione per Categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 42,
                        sectionsSpace: 3,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 650),
                      swapAnimationCurve: Curves.easeInOutCubic,
                    ),
                    Text(
                      formatDuration(totalSeconds),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: categoryDurations.entries.map((entry) {
                    final cat = entry.key;
                    final sec = entry.value;
                    final pct = totalSeconds > 0 ? (sec / totalSeconds * 100).toInt() : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: cat.defaultColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat.displayName,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: cat.defaultColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyBarChartSection extends StatelessWidget {
  final Map<String, int> dailyDurations;
  final bool isDark;

  const _DailyBarChartSection({
    required this.dailyDurations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayFormat = DateFormat('E', 'it_IT');
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final barGroups = <BarChartGroupData>[];
    double maxHours = 4.0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final seconds = dailyDurations[dateKey] ?? 0;
      final hours = seconds / 3600.0;

      if (hours > maxHours) maxHours = hours;

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: hours,
              color: i == 0 ? AppColors.primary : (isDark ? AppColors.primaryLight.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.4)),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attività Ultimi 7 Giorni (Ore)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxHours * 1.2,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}h',
                        style: TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        final date = now.subtract(Duration(days: 6 - idx));
                        return Text(
                          dayFormat.format(date),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
              swapAnimationDuration: const Duration(milliseconds: 650),
              swapAnimationCurve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesRankingSection extends StatelessWidget {
  final Map<String, int> placesDuration;
  final int totalSeconds;
  final String Function(int) formatDuration;
  final bool isDark;

  const _PlacesRankingSection({
    required this.placesDuration,
    required this.totalSeconds,
    required this.formatDuration,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final entries = placesDuration.entries.toList();
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classifica Luoghi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final e = entries[idx];
              final pct = totalSeconds > 0 ? (e.value / totalSeconds) : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${idx + 1}. ${e.key}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      Text(
                        formatDuration(e.value),
                        style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: elevatedBg,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        idx == 0 ? AppColors.primary : AppColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
