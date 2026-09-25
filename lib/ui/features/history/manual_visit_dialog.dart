import 'package:flutter/material.dart';
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
    widget.onVisitAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _places.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Nessun Luogo Configurato',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea prima un luogo (es. Ufficio o Palestra) per poter aggiungere una visita manuale.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Chiudi'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Aggiungi Visita Manuale',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'LUOGO',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Place>(
                            value: _selectedPlace,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: _places.map((p) {
                              return DropdownMenuItem<Place>(
                                value: p,
                                child: Row(
                                  children: [
                                    Icon(p.icon, color: p.color, size: 20),
                                    const SizedBox(width: 10),
                                    Text(p.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (p) => setState(() => _selectedPlace = p),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'DATA',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                            ),
                            leading: const Icon(Icons.calendar_today_rounded),
                            title: Text(dateFormat.format(_date)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: _selectDate,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ORA INIZIO',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                                      ),
                                      title: Text(_startTime.format(context)),
                                      onTap: _selectStartTime,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ORA FINE',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                                      ),
                                      title: Text(_endTime.format(context)),
                                      onTap: _selectEndTime,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'NOTE (OPZIONALE)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              hintText: 'Es. Sessione straordinari o allenamento gambe',
                            ),
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
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Annulla'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _save,
                                  child: const Text(
                                    'Aggiungi',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
