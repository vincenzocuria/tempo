import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../history/history_view.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      child: SelectableText(
                        content,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

    final csv = ExportService.exportVisitsToCsv(visits: visits, places: places);
    _showExportPreview('Esportazione CSV', csv);
  }

  void _exportJson() async {
    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);

    final places = await placeRepo.getAllPlaces();
    final visits = await visitRepo.getVisits();

    final json = ExportService.exportDataToJson(places: places, visits: visits);
    _showExportPreview('Esportazione JSON', json);
  }

  void _seedDemo() async {
    final visitRepo = Provider.of<VisitRepository>(context, listen: false);
    await visitRepo.seedDemoData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dati demo aggiunti con successo! Controlla la Dashboard e le Statistiche.'),
        ),
      );
    }
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancella Tutti i Dati?'),
        content: const Text(
          'Questa azione eliminerà permanentemente tutti i luoghi e le visite salvate sul tuo dispositivo. Non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final visitRepo = Provider.of<VisitRepository>(context, listen: false);
              await visitRepo.clearAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tutti i dati sono stati cancellati.')),
                );
              }
            },
            child: const Text('Cancella Tutto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<TrackingEngine>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  AppColors.success.withOpacity(0.18),
                  AppColors.success.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.success.withOpacity(0.3),
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
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Tracciamento Automatico',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    engine.isTrackingEnabled
                        ? 'Attivo • Controlla l\'ingresso/uscita dai luoghi'
                        : 'Sospeso • Nessun calcolo in background',
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
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                _PermissionTile(
                  title: 'Posizione GPS',
                  subtitle: 'Richiesta per determinare le coordinate',
                  isGranted: _locationStatus.isGranted,
                  onTap: _requestLocation,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _PermissionTile(
                  title: 'Posizione in Background (Sempre)',
                  subtitle: 'Consente di calcolare le ore a schermo spento',
                  isGranted: _bgLocationStatus.isGranted,
                  onTap: _requestBgLocation,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: SwitchListTile(
              title: const Text(
                'Tema Scuro',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(widget.isDarkMode ? 'Attivo' : 'Tema Chiaro'),
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
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: AppColors.primary),
                  title: const Text('Cronologia Completa Visite', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Visualizza e cerca tutte le sessioni passate'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryView()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart_rounded, color: AppColors.primaryLight),
                  title: const Text('Esporta Visite in CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Compatibile con Excel e Google Fogli'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: _exportCsv,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: AppColors.primaryLight),
                  title: const Text('Esporta Tutto in JSON', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Backup completo di luoghi e visite'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: _exportJson,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_rounded, color: AppColors.warning),
                  title: const Text('Carica Dati Demo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Popola 5 giorni di test con Lavoro, Palestra e Casa'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.danger.withOpacity(0.3),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              title: const Text(
                'Cancella Tutti i Dati',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
              ),
              subtitle: const Text('Elimina luoghi e cronologia dal dispositivo'),
              onTap: _confirmClearData,
            ),
          ),
          const SizedBox(height: 36),

          // App Info footer
          Center(
            child: Column(
              children: [
                Text(
                  'Tempo v1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Presenza & Tempo • Senza Cloud • 100% Privacy',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Color(0xFF94A3B8),
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
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isGranted
          ? const Chip(
              label: Text('Concesso'),
              backgroundColor: Color(0xFF10B981),
              labelStyle: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: onTap,
              child: const Text('Abilita'),
            ),
      onTap: onTap,
    );
  }
}
