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

  const DashboardView({
    super.key,
    required this.onNavigateToHistory,
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

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Seleziona Luogo per Check-in',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: places.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (c, idx) {
                      final p = places[idx];
                      final isCurrent = engine.currentPlace?.id == p.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCurrent
                                ? p.color
                                : Theme.of(context).dividerColor.withOpacity(0.1),
                          ),
                        ),
                        tileColor: p.color.withOpacity(0.08),
                        leading: CircleAvatar(
                          backgroundColor: p.color.withOpacity(0.2),
                          child: Icon(p.icon, color: p.color),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(p.category.displayName),
                        trailing: isCurrent
                            ? const Chip(
                                label: Text('Attuale'),
                                backgroundColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          engine.manualCheckIn(p);
                        },
                      );
                    },
                  ),
                ),
              ],
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
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const PlaceFormDialog(),
                      );
                    },
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
