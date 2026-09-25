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
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text(
                      'Nessun dato per questo intervallo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'I dati compariranno automaticamente man mano che visiti i tuoi luoghi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
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
    final sections = <PieChartSectionData>[];

    categoryDurations.forEach((cat, sec) {
      if (sec > 0 && totalSeconds > 0) {
        sections.add(
          PieChartSectionData(
            value: sec.toDouble(),
            color: cat.defaultColor,
            radius: 38,
            showTitle: false,
          ),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuzione per Categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

    final barGroups = <BarChartGroupData>[];
    double maxHours = 8.0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final sec = dailyDurations[dateStr] ?? 0;
      final hours = sec / 3600.0;
      if (hours > maxHours) maxHours = hours;

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: hours,
              color: i == 0 ? AppColors.primaryLight : AppColors.primary,
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
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attività Ultimi 7 Giorni (Ore)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classifica Luoghi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatDuration(e.value),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurfaceElevated,
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
