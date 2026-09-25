import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../places/place_form_dialog.dart';
import 'dashboard_view_model.dart';
import 'widgets/live_status_card.dart';
import 'widgets/recent_visits_list.dart';
import 'widgets/today_summary_row.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback onNavigateToHistory;
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const DashboardView({
    super.key,
    required this.onNavigateToHistory,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  void _showQuickCheckInSheet(BuildContext context, TrackingEngine engine) async {
    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final places = await placeRepo.getAllPlaces();

    if (!context.mounted) return;

    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi prima un luogo (es. Lavoro, Palestra) per fare il check-in.'),
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
                        'Check-in Manuale',
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
                        final isCurrent = engine.currentPlace?.id == p.id;
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
                            trailing: isCurrent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: p.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Attuale',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                            onTap: () {
                              Navigator.pop(ctx);
                              engine.manualCheckIn(p);
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
    final viewModel = Provider.of<DashboardViewModel>(context);
    final trackingEngine = Provider.of<TrackingEngine>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.timelapse_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Tempo'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDarkMode ? 'Passa al Tema Chiaro' : 'Passa al Tema Scuro',
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDarkMode ? AppColors.warning : AppColors.primary,
            ),
            onPressed: onThemeToggle,
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withOpacity(0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppColors.success,
                ),
                SizedBox(width: 4),
                Text(
                  '100% Locale',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => viewModel.refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            LiveStatusCard(
              trackingEngine: trackingEngine,
              onQuickCheckInTap: () => _showQuickCheckInSheet(context, trackingEngine),
            ),
            const SizedBox(height: 20),
            TodaySummaryRow(
              formattedTotal: viewModel.formattedTotalToday,
              topPlace: viewModel.topPlaceToday,
              visitCount: viewModel.todayVisits.length,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => PlaceFormDialog.show(context),
                    icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                    label: const Text(
                      'Nuovo Luogo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            RecentVisitsList(
              visits: viewModel.todayVisits,
              onViewAllTap: onNavigateToHistory,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
