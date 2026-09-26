import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../notifications/notification_log_sheet.dart';
import '../onboarding/onboarding_view.dart';
import '../places/place_form_dialog.dart';
import 'dashboard_view_model.dart';
import 'widgets/habit_suggestion_card.dart';
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

  String _formattedItalianDate(DateTime dt) {
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
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, ${dt.day} $monthName';
  }

  Widget _buildLiveStatusBadge(
    BuildContext context,
    TrackingEngine engine,
    bool isDark,
  ) {
    final activeVisit = engine.activeVisit;
    final currentPlace = engine.currentPlace;
    final activeTrip = engine.activeTrip;

    final Color badgeColor;
    final String badgeLabel;

    if (activeVisit != null && currentPlace != null) {
      badgeColor = currentPlace.color;
      badgeLabel = currentPlace.name;
    } else if (activeTrip != null) {
      badgeColor = const Color(0xFF0EA5E9);
      badgeLabel = 'In viaggio';
    } else {
      badgeColor = const Color(0xFFF59E0B);
      badgeLabel = 'Fuori dai Luoghi';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context, bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return Consumer<NotificationService>(
      builder: (context, notifService, _) {
        final unread = notifService.unreadCount;
        return IconButton(
          tooltip: 'Registro Notifiche',
          style: IconButton.styleFrom(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            padding: const EdgeInsets.all(8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => NotificationLogSheet.show(context, isDark: isDark),
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.primary,
            label: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            child: Icon(
              unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
              size: 19,
              color: unread > 0 ? AppColors.primary : textMuted,
            ),
          ),
        );
      },
    );
  }

  void _showQuickCheckInSheet(BuildContext context, TrackingEngine engine) async {
    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final places = await placeRepo.getAllPlaces();

    if (!context.mounted) return;

    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi prima un luogo (es. Casa, Ufficio, Studio) per fare il check-in.'),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final now = DateTime.now();
    final dateString = _formattedItalianDate(now);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => viewModel.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Executive Top Navigation Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Brand Chip
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.timelapse_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TEMPO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 11,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '100% Locale',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Actions: Notification Bell with Badge, Help/Guide & Theme Toggle
                  Row(
                    children: [
                      _buildNotificationBell(context, isDarkMode),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Guida Rapida',
                        style: IconButton.styleFrom(
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor),
                          ),
                          padding: const EdgeInsets.all(8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(
                          Icons.help_outline_rounded,
                          size: 19,
                          color: textMuted,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OnboardingView(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: isDarkMode ? 'Tema Chiaro' : 'Tema Scuro',
                        style: IconButton.styleFrom(
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor),
                          ),
                          padding: const EdgeInsets.all(8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(
                          isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 19,
                          color: isDarkMode ? AppColors.warning : AppColors.primary,
                        ),
                        onPressed: onThemeToggle,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Date & Title Header with Live Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateString.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Riepilogo Oggi',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  _buildLiveStatusBadge(context, trackingEngine, isDark),
                ],
              ),
              const SizedBox(height: 18),

              // Live Status Card
              LiveStatusCard(
                trackingEngine: trackingEngine,
                onQuickCheckInTap: () => _showQuickCheckInSheet(context, trackingEngine),
              ),
              const SizedBox(height: 18),

              // Smart Habit Suggestions (if detected)
              ListenableBuilder(
                listenable: trackingEngine.habitService,
                builder: (context, _) {
                  final suggestions = trackingEngine.habitService.pendingSuggestions;
                  if (suggestions.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: suggestions
                          .map((s) => HabitSuggestionCard(
                                suggestion: s,
                                onDismissed: () => viewModel.refresh(),
                                onSaved: () => viewModel.refresh(),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),

              // Today Summary Row (Total Time, Top Place, & Trips)
              TodaySummaryRow(
                formattedTotal: viewModel.formattedTotalToday,
                topPlace: viewModel.topPlaceToday,
                visitCount: viewModel.todayVisits.length,
                tripCount: viewModel.todayTrips.length,
                formattedDistance: viewModel.formattedTotalDistanceToday,
                formattedTripDuration: viewModel.formattedTotalTripDurationToday,
              ),
              const SizedBox(height: 20),

              // Modern Quick Action Bar (3 Segmented Cards)
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.add_location_alt_rounded,
                      label: 'Nuovo Luogo',
                      accentColor: AppColors.primary,
                      onTap: () => PlaceFormDialog.show(context),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.touch_app_rounded,
                      label: 'Check-in',
                      accentColor: const Color(0xFF6366F1),
                      onTap: () => _showQuickCheckInSheet(context, trackingEngine),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.calendar_month_rounded,
                      label: 'Cronologia',
                      accentColor: const Color(0xFF06B6D4),
                      onTap: onNavigateToHistory,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // Recent Activity Feed (Visits & Trips)
              RecentVisitsList(
                visits: viewModel.todayVisits,
                trips: viewModel.todayTrips,
                onViewAllTap: onNavigateToHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
