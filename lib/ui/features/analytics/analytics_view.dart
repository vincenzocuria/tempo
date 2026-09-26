import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place_category.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../history/manual_visit_dialog.dart';
import '../places/places_view_model.dart';
import 'analytics_view_model.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AnalyticsViewModel>(context, listen: false).loadAnalytics();
      }
    });
  }

  void _showQuickCheckIn(BuildContext context) async {
    final placesVm = Provider.of<PlacesViewModel>(context, listen: false);
    final trackingEngine = Provider.of<TrackingEngine>(context, listen: false);
    final places = placesVm.places;

    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi prima un luogo nella scheda "Luoghi" per fare il check-in.'),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Check-in Rapido',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          padding: const EdgeInsets.all(6),
                        ),
                        icon: Icon(Icons.close_rounded, size: 20, color: textPrimary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (c, idx) {
                        final p = places[idx];
                        final isCurrent = trackingEngine.currentPlace?.id == p.id;
                        return Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? p.color.withValues(alpha: isDark ? 0.2 : 0.1)
                                : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isCurrent ? p.color : borderColor,
                              width: isCurrent ? 1.8 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: p.color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(p.icon, color: p.color, size: 20),
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                            subtitle: Text(
                              p.category.displayName,
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await trackingEngine.manualCheckIn(p);
                              if (context.mounted) {
                                Provider.of<AnalyticsViewModel>(context, listen: false).loadAnalytics();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalyticsViewModel>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final hasAnyData = viewModel.totalDurationSeconds > 0 || viewModel.totalTripsCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche & Ore'),
        actions: [
          IconButton(
            tooltip: 'Aggiungi visita manuale',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => ManualVisitDialog.show(
              context,
              onVisitAdded: () => viewModel.loadAnalytics(),
            ),
          ),
        ],
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

            // Top Spotlight Cards (Dynamic based on real visited places)
            Row(
              children: [
                Expanded(
                  child: _HeroMetricCard(
                    title: 'TEMPO TOTALE',
                    value: viewModel.formatSeconds(viewModel.totalDurationSeconds),
                    subtitle: '${viewModel.placesVisitedCount} ${viewModel.placesVisitedCount == 1 ? "luogo" : "luoghi"}',
                    icon: Icons.hourglass_bottom_rounded,
                    accentColor: AppColors.primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _HeroMetricCard(
                    title: 'LUOGO PRINCIPALE',
                    value: viewModel.topPlace?.key ?? (hasAnyData ? 'Nessuno' : 'In attesa'),
                    subtitle: viewModel.topPlace != null
                        ? viewModel.formatSeconds(viewModel.topPlace!.value)
                        : (hasAnyData ? '0m' : 'Registra soste'),
                    icon: Icons.stars_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Trips / Spostamenti Hero Metric
            if (viewModel.totalTripsCount > 0) ...[
              _HeroMetricCard(
                title: 'SPOSTAMENTI & TRAGITTI',
                value: '${viewModel.totalTripsCount} ${viewModel.totalTripsCount == 1 ? "viaggio" : "viaggi"}',
                subtitle: '${viewModel.formatDistance(viewModel.totalTripDistanceMeters)} percorsi • ${viewModel.formatSeconds(viewModel.totalTripDurationSeconds)} in transito',
                icon: Icons.directions_car_rounded,
                accentColor: const Color(0xFF0EA5E9),
                isDark: isDark,
              ),
              const SizedBox(height: 14),
            ],

            // Quick Horizontal Place Chips if multiple places
            if (viewModel.sortedPlaces.length > 2) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: viewModel.sortedPlaces.skip(2).map((entry) {
                    final pct = viewModel.totalDurationSeconds > 0
                        ? (entry.value / viewModel.totalDurationSeconds * 100).toInt()
                        : 0;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_rounded, size: 14, color: textMuted),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${viewModel.formatSeconds(entry.value)} ($pct%)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (viewModel.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!hasAnyData)
              // Interactive, rich empty state that explains how to start tracking
              Container(
                padding: const EdgeInsets.all(24),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.query_stats_rounded, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nessuna attività in questo intervallo',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Non risultano soste registrate per "${viewModel.selectedFilter.displayName}". Effettua un check-in ora o aggiungi una visita passata.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.touch_app_rounded, size: 16),
                            label: const Text('Check-in ora', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => _showQuickCheckIn(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Visita manuale', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => ManualVisitDialog.show(
                              context,
                              onVisitAdded: () => viewModel.loadAnalytics(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (viewModel.selectedFilter != AnalyticsTimeFilter.allTime) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => viewModel.setFilter(AnalyticsTimeFilter.allTime),
                        child: const Text(
                          'Mostra statistiche di sempre (Tutto)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              // Pie Chart: Distribution by Category
              if (viewModel.durationByCategory.isNotEmpty) ...[
                _CategoryPieChartSection(
                  categoryDurations: viewModel.durationByCategory,
                  totalSeconds: viewModel.totalDurationSeconds,
                  formatDuration: viewModel.formatSeconds,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
              ],

              // Bar Chart: Daily Trend for the Last 7 Days
              _DailyBarChartSection(
                dailyDurations: viewModel.dailyDurations,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // Top Places Ranking List
              if (viewModel.durationByPlace.isNotEmpty) ...[
                _PlacesRankingSection(
                  placesDuration: viewModel.durationByPlace,
                  totalSeconds: viewModel.totalDurationSeconds,
                  formatDuration: viewModel.formatSeconds,
                  isDark: isDark,
                ),
                const SizedBox(height: 28),
              ],
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
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDark;

  const _HeroMetricCard({
    required this.title,
    required this.value,
    this.subtitle,
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeInOutCubic,
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

  static const List<String> _weekdaysIt = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final barGroups = <BarChartGroupData>[];
    double maxHours = 4.0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final seconds = dailyDurations[dateKey] ?? 0;
      final hours = seconds / 3600.0;

      if (hours > maxHours) maxHours = hours;

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: hours,
              color: i == 0
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.primaryLight.withValues(alpha: 0.6)
                      : AppColors.primary.withValues(alpha: 0.4)),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    final double maxYValue = max(4.0, (maxHours * 1.25).ceilToDouble());
    final double leftInterval = max(1.0, (maxYValue / 4).ceilToDouble());

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
                minY: 0.0,
                maxY: maxYValue,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: leftInterval,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}h',
                        style: TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        final date = now.subtract(Duration(days: 6 - idx));
                        final label = _weekdaysIt[date.weekday - 1];
                        return Text(
                          label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOutCubic,
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
    entries.sort((a, b) => b.value.compareTo(a.value));

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
                      value: pct.clamp(0.0, 1.0),
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
