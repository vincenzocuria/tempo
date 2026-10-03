import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/trip_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../data/models/trip.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/habit_detection_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../analytics/analytics_view_model.dart';
import '../dashboard/dashboard_view_model.dart';
import '../../../data/services/permission_manager.dart';
import '../categories/categories_view.dart';
import '../history/history_view.dart';
import '../notifications/notification_log_sheet.dart';
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

class _SettingsViewState extends State<SettingsView>
    with WidgetsBindingObserver {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _bgLocationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final status = await PermissionManager.instance.checkAllStatus();

    if (mounted) {
      setState(() {
        _locationStatus = status.locationGranted
            ? PermissionStatus.granted
            : PermissionStatus.denied;
        _bgLocationStatus = status.backgroundLocationGranted
            ? PermissionStatus.granted
            : PermissionStatus.denied;
        _notificationStatus = status.notificationGranted
            ? PermissionStatus.granted
            : PermissionStatus.denied;
        _batteryOptimizationIgnored = status.batteryOptimizationIgnored;
      });
    }
  }

  Future<void> _requestLocation() async {
    await PermissionManager.instance.requestForegroundLocation();
    await _checkPermissions();
  }

  Future<void> _requestBgLocation() async {
    await PermissionManager.instance.requestBackgroundLocation(context);
    await _checkPermissions();
  }

  Future<void> _requestNotification() async {
    await PermissionManager.instance.requestNotifications();
    await _checkPermissions();
  }

  Future<void> _requestBatteryOptimization() async {
    await PermissionManager.instance.requestBatteryOptimization();
    await _checkPermissions();
  }

  void _showExportPreview(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textDarkPrimary
        : AppColors.textLightPrimary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final elevatedBg = isDark
        ? AppColors.darkSurfaceElevated
        : AppColors.lightSurfaceElevated;
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
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
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
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
                          const SnackBar(
                            content: Text('Copiato negli appunti!'),
                          ),
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
    try {
      final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
      final visitRepo = Provider.of<VisitRepository>(context, listen: false);

      final places = await placeRepo.getAllPlaces();
      final visits = await visitRepo.getVisits();

      if (!mounted) return;
      final csv = ExportService.exportVisitsToCsv(
        visits: visits,
        places: places,
      );
      _showExportPreview('Esportazione CSV', csv);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esportazione non riuscita. Riprova.')),
        );
      }
    }
  }

  void _exportJson() async {
    try {
      final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
      final visitRepo = Provider.of<VisitRepository>(context, listen: false);

      final tripRepo = context.read<TripRepository>();
      final categories = context
          .read<CategoryRepository>()
          .customCategories
          .toList();
      final places = await placeRepo.getAllPlaces();
      final visits = await visitRepo.getVisits();
      final trips = await tripRepo.getTrips();

      if (!mounted) return;
      final json = ExportService.exportDataToJson(
        places: places,
        visits: visits,
        trips: trips,
        customCategories: categories,
      );
      _showExportPreview('Esportazione JSON', json);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esportazione non riuscita. Riprova.')),
        );
      }
    }
  }

  void _confirmClearData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textDarkPrimary
        : AppColors.textLightPrimary;
    final textMuted = isDark
        ? AppColors.textDarkMuted
        : AppColors.textLightMuted;
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
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.danger,
                  size: 34,
                ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Annulla',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final dashboardVm = Provider.of<DashboardViewModel>(
                          context,
                          listen: false,
                        );
                        final placesVm = Provider.of<PlacesViewModel>(
                          context,
                          listen: false,
                        );
                        final analyticsVm = Provider.of<AnalyticsViewModel>(
                          context,
                          listen: false,
                        );
                        final trackingEngine = Provider.of<TrackingEngine>(
                          context,
                          listen: false,
                        );

                        await trackingEngine.clearAllData();
                        if (!mounted) return;
                        context.read<CategoryRepository>().clearRegistry();
                        await dashboardVm.loadData();
                        await placesVm.loadPlaces();
                        await analyticsVm.loadAnalytics();

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tutti i dati sono stati cancellati.',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Cancella Tutto',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
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
    final textPrimary = isDark
        ? AppColors.textDarkPrimary
        : AppColors.textLightPrimary;
    final textMuted = isDark
        ? AppColors.textDarkMuted
        : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni & Privacy')),
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
                    Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
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
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
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
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Tracciamento Luoghi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      engine.isTrackingEnabled
                          ? 'Attivo • Monitora soste e geofence'
                          : 'Sospeso • Nessun calcolo in background',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    value: engine.isTrackingEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) => engine.setTrackingEnabled(val),
                  ),
                  Divider(height: 1, color: borderColor),
                  SwitchListTile(
                    title: Text(
                      'Registra Tragitti & Spostamenti',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      engine.isTripTrackingEnabled
                          ? 'Attivo • Traccia tragitti, distanze e tempi all\'uscita dall\'area'
                          : 'Disattivato • Non registra gli spostamenti tra luoghi',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    value: engine.isTripTrackingEnabled,
                    activeColor: const Color(0xFF0EA5E9),
                    onChanged: (val) => engine.setTripTrackingEnabled(val),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            (engine.preferredMotorVehicle == TransportMode.moto
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFF0284C7))
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        engine.preferredMotorVehicle == TransportMode.moto
                            ? Icons.two_wheeler_rounded
                            : Icons.directions_car_rounded,
                        color:
                            engine.preferredMotorVehicle == TransportMode.moto
                            ? const Color(0xFFF97316)
                            : const Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'Mezzo a Motore Predefinito',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      engine.preferredMotorVehicle == TransportMode.moto
                          ? 'Moto / Scooter (priorità due ruote)'
                          : 'Auto (priorità automobile)',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: TransportMode.auto,
                          icon: Icon(Icons.directions_car_rounded, size: 16),
                          label: Text(
                            'Auto',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ButtonSegment<String>(
                          value: TransportMode.moto,
                          icon: Icon(Icons.two_wheeler_rounded, size: 16),
                          label: Text(
                            'Moto',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      selected: {engine.preferredMotorVehicle},
                      onSelectionChanged: (newSelection) {
                        if (newSelection.isNotEmpty) {
                          engine.setPreferredMotorVehicle(newSelection.first);
                        }
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
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
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  _PermissionTile(
                    title: 'Posizione GPS',
                    subtitle: 'Richiesta per determinare le coordinate',
                    isGranted: _locationStatus.isGranted,
                    onTap: _requestLocation,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  _PermissionTile(
                    title: 'Posizione in Background (Sempre)',
                    subtitle: 'Consente di calcolare le ore a schermo spento',
                    isGranted: _bgLocationStatus.isGranted,
                    onTap: _requestBgLocation,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  _PermissionTile(
                    title: 'Notifiche',
                    subtitle: 'Avvisi di ingresso e riepilogo uscita',
                    isGranted: _notificationStatus.isGranted,
                    onTap: _requestNotification,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  _PermissionTile(
                    title: 'Nessuna Restrizione Batteria',
                    subtitle: 'Essenziale per Samsung / OneUI per non chiudere il servizio',
                    isGranted: _batteryOptimizationIgnored,
                    onTap: _requestBatteryOptimization,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons.settings_suggest_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        'Apri Impostazioni App di Sistema',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Gestisci manualmente tutti i permessi nelle impostazioni Android',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () =>
                          PermissionManager.instance.openSystemSettings(),
                    ),
                  ),
                ],
              ),
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
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                title: Text(
                  'Tema Scuro',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  widget.isDarkMode ? 'Attivo' : 'Disattivato (Tema Chiaro)',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                value: widget.isDarkMode,
                activeColor: AppColors.primary,
                onChanged: (_) => widget.onThemeToggle(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Customization & Categories
          _SectionHeader(title: 'PERSONALIZZAZIONE'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
                title: Text(
                  'Gestione Categorie',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Aggiungi, modifica ed elimina le categorie dei luoghi',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: textMuted,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesView()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Notifiche & Registro
          _SectionHeader(title: 'NOTIFICHE & REGISTRO'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Consumer<NotificationService>(
              builder: (context, notifService, _) {
                final unread = notifService.unreadCount;
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        unread > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Registro Notifiche',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Storico permanente di arrivi, partenze e abitudini',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread nuove',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: textMuted,
                        ),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      NotificationLogSheet.show(
                        context,
                        isDark: widget.isDarkMode,
                      );
                    },
                  ),
                );
              },
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
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Cronologia Completa Visite',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Visualizza e cerca tutte le sessioni passate',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryView()),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.table_chart_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Esporta Visite in CSV',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Compatibile con Excel e Google Fogli',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                    onTap: _exportCsv,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.code_rounded,
                      color: AppColors.info,
                    ),
                    title: Text(
                      'Esporta Tutto in JSON',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Backup completo di luoghi e visite',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                    onTap: _exportJson,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF6366F1),
                    ),
                    title: Text(
                      'Simula Rilevamento Luogo Frequente',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Simula una sosta abituale per testare i suggerimenti smart',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                    onTap: () async {
                      await HabitDetectionService.instance.simulateHabitStay();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Luogo frequente simulato con successo! Controlla la schermata "Oggi".',
                            ),
                            backgroundColor: Color(0xFF6366F1),
                          ),
                        );
                      }
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: borderColor,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Rivedi Guida & Onboarding',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Rivedi le slide introduttive e la filosofia di Tempo',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingView(),
                        ),
                      );
                    },
                  ),
                ],
              ),
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
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Cancella Tutti i Dati',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                subtitle: Text(
                  'Elimina luoghi e cronologia dal dispositivo',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                onTap: _confirmClearData,
              ),
            ),
          ),
          const SizedBox(height: 36),

          // App Info footer
          Center(
            child: Column(
              children: [
                Text(
                  'Tempo v1.0.25',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Presenza & Tempo • Senza Cloud • 100% Privacy',
                  style: TextStyle(fontSize: 11, color: textMuted),
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
    final textMuted = isDark
        ? AppColors.textDarkMuted
        : AppColors.textLightMuted;

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
    final textPrimary = isDark
        ? AppColors.textDarkPrimary
        : AppColors.textLightPrimary;
    final textMuted = isDark
        ? AppColors.textDarkMuted
        : AppColors.textLightMuted;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        trailing: isGranted
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Concesso',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onTap,
                child: const Text('Abilita'),
              ),
        onTap: onTap,
      ),
    );
  }
}
