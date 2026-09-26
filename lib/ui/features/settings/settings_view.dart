import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/habit_detection_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../analytics/analytics_view_model.dart';
import '../dashboard/dashboard_view_model.dart';
import '../history/history_view.dart';
import '../onboarding/onboarding_view.dart';
import '../places/places_view_model.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const SettingsView({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _bgLocationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final loc = await Permission.location.status;
    final bg = await Permission.locationAlways.status;
    final notif = await Permission.notification.status;

    if (mounted) {
      setState(() {
        _locationStatus = loc;
        _bgLocationStatus = bg;
        _notificationStatus = notif;
      });
    }
  }

  Future<void> _requestLocation() async {
    await LocationService.instance.requestLocationPermission();
    await _checkPermissions();
  }

  Future<void> _requestBgLocation() async {
    await LocationService.instance.requestBackgroundLocation();
    await _checkPermissions();
  }

  Future<void> _requestNotification() async {
    await NotificationService.instance.requestPermission();
    await _checkPermissions();
  }

  void _showExportPreview(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
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
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: 'Copia negli appunti',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copiato negli appunti!')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: elevatedBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _exportCsv() async {
    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);

    final places = await placeRepo.getAllPlaces();
    final visits = await visitRepo.getVisits();

    if (!mounted) return;
    final csv = ExportService.exportVisitsToCsv(visits: visits, places: places);
    _showExportPreview('Esportazione CSV', csv);
  }

  void _exportJson() async {
    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);

    final places = await placeRepo.getAllPlaces();
    final visits = await visitRepo.getVisits();

    if (!mounted) return;
    final json = ExportService.exportDataToJson(places: places, visits: visits);
    _showExportPreview('Esportazione JSON', json);
  }

  void _seedDemo() async {
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);
    final dashboardVm = Provider.of<DashboardViewModel>(context, listen: false);
    final placesVm = Provider.of<PlacesViewModel>(context, listen: false);
    final analyticsVm = Provider.of<AnalyticsViewModel>(context, listen: false);

    await visitRepo.seedDemoData();
    await dashboardVm.loadData();
    await placesVm.loadPlaces();
    await analyticsVm.loadAnalytics();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dati demo aggiunti con successo! Dashboard, Luoghi e Statistiche aggiornati.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _confirmClearData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                'Cancellare Tutti i Dati?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Questa operazione eliminerà permanentemente tutti i luoghi e le visite salvate sul tuo telefono. Non può essere annullata.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Annulla', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final visitRepo = Provider.of<VisitRepository>(context, listen: false);
                        final dashboardVm = Provider.of<DashboardViewModel>(context, listen: false);
                        final placesVm = Provider.of<PlacesViewModel>(context, listen: false);
                        final analyticsVm = Provider.of<AnalyticsViewModel>(context, listen: false);
                        final trackingEngine = Provider.of<TrackingEngine>(context, listen: false);

                        await visitRepo.clearAllData();
                        await trackingEngine.manualCheckOut();
                        await dashboardVm.loadData();
                        await placesVm.loadPlaces();
                        await analyticsVm.loadAnalytics();

                        messenger.showSnackBar(
                          const SnackBar(content: Text('Tutti i dati sono stati cancellati.')),
                        );
                      },
                      child: const Text('Cancella Tutto', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<TrackingEngine>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni & Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: isDark ? 0.2 : 0.14),
                  AppColors.success.withValues(alpha: isDark ? 0.05 : 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppColors.success, size: 24),
                    SizedBox(width: 10),
                    Text(
                      '100% Privacy & Locale',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tempo funziona interamente offline sul tuo dispositivo. Nessun server esterno, nessun account di terze parti, nessuna condivisione dei dati di posizione.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tracking control
          _SectionHeader(title: 'MONITORAGGIO'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Tracciamento Automatico',
                    style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  subtitle: Text(
                    engine.isTrackingEnabled
                        ? 'Attivo • Controlla l\'ingresso/uscita dai luoghi'
                        : 'Sospeso • Nessun calcolo in background',
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                  value: engine.isTrackingEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (val) => engine.setTrackingEnabled(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Permissions
          _SectionHeader(title: 'AUTORIZZAZIONI DI SISTEMA'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _PermissionTile(
                  title: 'Posizione GPS',
                  subtitle: 'Richiesta per determinare le coordinate',
                  isGranted: _locationStatus.isGranted,
                  onTap: _requestLocation,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                _PermissionTile(
                  title: 'Posizione in Background (Sempre)',
                  subtitle: 'Consente di calcolare le ore a schermo spento',
                  isGranted: _bgLocationStatus.isGranted,
                  onTap: _requestBgLocation,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                _PermissionTile(
                  title: 'Notifiche',
                  subtitle: 'Avvisi di ingresso e riepilogo uscita',
                  isGranted: _notificationStatus.isGranted,
                  onTap: _requestNotification,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance
          _SectionHeader(title: 'ASPETTO'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: SwitchListTile(
              title: Text(
                'Tema Scuro',
                style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
              ),
              subtitle: Text(widget.isDarkMode ? 'Attivo' : 'Disattivato (Tema Chiaro)', style: TextStyle(color: textMuted, fontSize: 13)),
              value: widget.isDarkMode,
              activeColor: AppColors.primary,
              onChanged: (_) => widget.onThemeToggle(),
            ),
          ),
          const SizedBox(height: 24),

          // Data ownership
          _SectionHeader(title: 'I TUOI DATI'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: AppColors.primary),
                  title: Text('Cronologia Completa Visite', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  subtitle: Text('Visualizza e cerca tutte le sessioni passate', style: TextStyle(color: textMuted, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryView()),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.table_chart_rounded, color: AppColors.primary),
                  title: Text('Esporta Visite in CSV', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  subtitle: Text('Compatibile con Excel e Google Fogli', style: TextStyle(color: textMuted, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onTap: _exportCsv,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: AppColors.info),
                  title: Text('Esporta Tutto in JSON', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  subtitle: Text('Backup completo di luoghi e visite', style: TextStyle(color: textMuted, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onTap: _exportJson,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
                  title: Text('Simula Rilevamento Luogo Frequente', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  subtitle: Text('Simula una sosta abituale per testare i suggerimenti smart', style: TextStyle(color: textMuted, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onTap: () async {
                    await HabitDetectionService.instance.simulateHabitStay();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Luogo frequente simulato con successo! Controlla la schermata "Oggi".'),
                          backgroundColor: Color(0xFF6366F1),
                        ),
                      );
                    }
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.school_rounded, color: AppColors.primary),
                  title: Text('Rivedi Guida & Onboarding', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  subtitle: Text('Rivedi le slide introduttive e la filosofia di Tempo', style: TextStyle(color: textMuted, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingView(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_rounded, color: AppColors.warning),
                  title: Text('Carica Dati Demo', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  subtitle: Text('Popola 5 giorni con Ufficio, Casa Principale e Seconda Casa', style: TextStyle(color: textMuted, fontSize: 13)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                  onTap: _seedDemo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          _SectionHeader(title: 'ZONA PERICOLOSA'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              title: const Text(
                'Cancella Tutti i Dati',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
              ),
              subtitle: Text('Elimina luoghi e cronologia dal dispositivo', style: TextStyle(color: textMuted, fontSize: 13)),
              onTap: _confirmClearData,
            ),
          ),
          const SizedBox(height: 36),

          // App Info footer
          Center(
            child: Column(
              children: [
                Text(
                  'Tempo v1.0.2',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Presenza & Tempo • Senza Cloud • 100% Privacy',
                  style: TextStyle(
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: textMuted,
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
      trailing: isGranted
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Concesso',
                style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: onTap,
              child: const Text('Abilita'),
            ),
      onTap: onTap,
    );
  }
}
