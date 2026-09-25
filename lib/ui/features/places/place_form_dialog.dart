import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_category.dart';
import '../../../data/services/location_service.dart';
import 'places_view_model.dart';

class PlaceFormDialog extends StatefulWidget {
  final Place? placeToEdit;

  const PlaceFormDialog({super.key, this.placeToEdit});

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  late PlaceCategory _selectedCategory;
  late double _radiusInMeters;
  late Color _selectedColor;
  late bool _notifyOnEntry;
  late bool _notifyOnExit;
  bool _isFetchingGps = false;

  final List<Color> _colorOptions = const [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.placeToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _latController = TextEditingController(
      text: p != null ? p.latitude.toStringAsFixed(6) : '',
    );
    _lngController = TextEditingController(
      text: p != null ? p.longitude.toStringAsFixed(6) : '',
    );
    _selectedCategory = p?.category ?? PlaceCategory.lavoro;
    _radiusInMeters = p?.radiusInMeters ?? 100.0;
    _selectedColor = p != null ? p.color : _selectedCategory.defaultColor;
    _notifyOnEntry = p?.notifyOnEntry ?? true;
    _notifyOnExit = p?.notifyOnExit ?? true;

    // If new place and no coordinates, auto-attempt to get GPS
    if (widget.placeToEdit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentGps();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentGps() async {
    setState(() => _isFetchingGps = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lngController.text = pos.longitude.toStringAsFixed(6);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Posizione GPS rilevata con successo!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile ottenere il GPS. Assicurati che sia attivo.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingGps = false);
      }
    }
  }

  void _savePlace() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci coordinate GPS valide.')),
      );
      return;
    }

    final vm = Provider.of<PlacesViewModel>(context, listen: false);

    if (widget.placeToEdit != null) {
      final updated = widget.placeToEdit!.copyWith(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        latitude: lat,
        longitude: lng,
        radiusInMeters: _radiusInMeters,
        colorValue: _selectedColor.value,
        notifyOnEntry: _notifyOnEntry,
        notifyOnExit: _notifyOnExit,
      );
      vm.updatePlace(updated);
    } else {
      final newPlace = Place(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        latitude: lat,
        longitude: lng,
        radiusInMeters: _radiusInMeters,
        colorValue: _selectedColor.value,
        notifyOnEntry: _notifyOnEntry,
        notifyOnExit: _notifyOnExit,
      );
      vm.addPlace(newPlace);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.placeToEdit != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Modifica Luogo' : 'Nuovo Luogo',
                      style: const TextStyle(
                        fontSize: 22,
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

                // Name field
                const Text(
                  'NOME DEL LUOGO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Es. Ufficio, Palestra McFit, Casa...',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Inserisci un nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Category selector
                const Text(
                  'CATEGORIA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PlaceCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : cat.defaultColor,
                          ),
                          const SizedBox(width: 6),
                          Text(cat.displayName),
                        ],
                      ),
                      selectedColor: _selectedColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                            _selectedColor = cat.defaultColor;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // GPS Position section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COORDINATE GPS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    TextButton.icon(
                      onPressed: _isFetchingGps ? null : _getCurrentGps,
                      icon: _isFetchingGps
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: Text(_isFetchingGps ? 'Rilevamento...' : 'Usa Posizione Attuale'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitudine',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Richiesta' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitudine',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Richiesta' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Radius slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RAGGIO DI RILEVAMENTO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_radiusInMeters.toInt()} metri',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radiusInMeters,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  activeColor: _selectedColor,
                  onChanged: (val) => setState(() => _radiusInMeters = val),
                ),
                Text(
                  _radiusInMeters <= 80
                      ? 'Adatto per singoli uffici o stanze'
                      : _radiusInMeters <= 150
                          ? 'Ideale per palestre, aziende e negozi'
                          : 'Adatto per parchi, campus o grandi centri commerciali',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),

                // Color picker
                const Text(
                  'COLORE IDENTIFICATIVO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _colorOptions.map((c) {
                    final isPicked = _selectedColor.value == c.value;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isPicked
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isPicked
                              ? [
                                  BoxShadow(
                                    color: c.withOpacity(0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isPicked
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Notifications toggles
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Notifica all\'arrivo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Avvisa quando inizia la registrazione del tempo',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifyOnEntry,
                  activeColor: _selectedColor,
                  onChanged: (v) => setState(() => _notifyOnEntry = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Notifica alla partenza',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Mostra il riepilogo delle ore trascorse',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifyOnExit,
                  activeColor: _selectedColor,
                  onChanged: (v) => setState(() => _notifyOnExit = v),
                ),
                const SizedBox(height: 24),

                // Action buttons
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
                          backgroundColor: _selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _savePlace,
                        child: Text(
                          isEditing ? 'Aggiorna' : 'Salva Luogo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
