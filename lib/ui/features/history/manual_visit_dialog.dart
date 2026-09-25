import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/models/visit_session.dart';
import '../../../data/repositories/place_repository.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../core/app_colors.dart';

class ManualVisitDialog extends StatefulWidget {
  final VoidCallback onVisitAdded;

  const ManualVisitDialog({super.key, required this.onVisitAdded});

  static Future<void> show(BuildContext context, {required VoidCallback onVisitAdded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualVisitDialog(onVisitAdded: onVisitAdded),
    );
  }

  @override
  State<ManualVisitDialog> createState() => _ManualVisitDialogState();
}

class _ManualVisitDialogState extends State<ManualVisitDialog> {
  List<Place> _places = [];
  Place? _selectedPlace;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 30);
  final _notesController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final repo = Provider.of<PlaceRepository>(context, listen: false);
    final p = await repo.getAllPlaces();
    setState(() {
      _places = p;
      if (p.isNotEmpty) _selectedPlace = p.first;
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _save() async {
    if (_selectedPlace == null) return;

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'orario di fine deve essere dopo quello di inizio.')),
      );
      return;
    }

    final repo = Provider.of<VisitRepository>(context, listen: false);
    final visit = VisitSession(
      placeId: _selectedPlace!.id,
      placeName: _selectedPlace!.name,
      category: _selectedPlace!.category,
      startTime: start,
      endTime: end,
      durationSeconds: end.difference(start).inSeconds,
      isManual: true,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    await repo.addManualVisit(visit);
    HapticFeedback.mediumImpact();
    widget.onVisitAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'it_IT');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_toggle_off_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Aggiungi Visita',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: elevatedBg,
                    padding: const EdgeInsets.all(6),
                  ),
                  icon: Icon(Icons.close_rounded, size: 20, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _places.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 14),
                            Text(
                              'Nessun Luogo Configurato',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crea prima un luogo (es. Ufficio o Palestra) dalla scheda Luoghi per registrare una sessione passata.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Ho Capito'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          16,
                          20,
                          MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Place Picker
                            Text(
                              'LUOGO DA REGISTRARE',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: textMuted),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<Place>(
                              value: _selectedPlace,
                              dropdownColor: cardBg,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                fillColor: elevatedBg,
                              ),
                              items: _places.map((p) {
                                return DropdownMenuItem<Place>(
                                  value: p,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: p.color.withValues(alpha: 0.16),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(p.icon, color: p.color, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(p.name, style: TextStyle(color: textPrimary)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (p) => setState(() => _selectedPlace = p),
                            ),
                            const SizedBox(height: 18),

                            // Date Picker Card
                            Text(
                              'DATA DELLA VISITA',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: textMuted),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: elevatedBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      dateFormat.format(_date),
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.edit_calendar_rounded, size: 18, color: textMuted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Start & End Time
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ORA INIZIO',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: textMuted),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: _selectStartTime,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: elevatedBg,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.access_time_rounded, color: AppColors.info, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                _startTime.format(context),
                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ORA FINE',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: textMuted),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: _selectEndTime,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: elevatedBg,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.timelapse_rounded, color: AppColors.success, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                _endTime.format(context),
                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Notes
                            Text(
                              'NOTE (OPZIONALE)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: textMuted),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesController,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Es. Sessione straordinari o allenamento gambe',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Annulla', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 2,
                                    ),
                                    onPressed: _save,
                                    child: const Text('Salva Sessione', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
