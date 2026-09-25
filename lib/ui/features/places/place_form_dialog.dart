import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_category.dart';
import '../../../data/services/location_service.dart';
import '../../core/app_colors.dart';
import 'places_view_model.dart';

class PlaceFormDialog extends StatefulWidget {
  final Place? placeToEdit;
  final LatLng? initialLocation;

  const PlaceFormDialog({
    super.key,
    this.placeToEdit,
    this.initialLocation,
  });

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final MapController _mapController = MapController();

  late PlaceCategory _selectedCategory;
  late double _radiusInMeters;
  late Color _selectedColor;
  late bool _notifyOnEntry;
  late bool _notifyOnExit;

  late LatLng _selectedPoint;
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

  final List<String> _quickSuggestions = [
    'Ufficio',
    'Palestra',
    'Casa',
    'Studio',
    'Bar preferito',
    'Coworking',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.placeToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _selectedCategory = p?.category ?? PlaceCategory.lavoro;
    _radiusInMeters = p?.radiusInMeters ?? 100.0;
    _selectedColor = p != null ? p.color : _selectedCategory.defaultColor;
    _notifyOnEntry = p?.notifyOnEntry ?? true;
    _notifyOnExit = p?.notifyOnExit ?? true;

    if (p != null) {
      _selectedPoint = LatLng(p.latitude, p.longitude);
    } else if (widget.initialLocation != null) {
      _selectedPoint = widget.initialLocation!;
    } else {
      // Default to Rome coordinates as safe fallback
      _selectedPoint = const LatLng(41.9028, 12.4964);
      // Auto-fetch GPS
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentGps();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentGps() async {
    setState(() => _isFetchingGps = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _selectedPoint = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_selectedPoint, 16.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Posizione GPS agganciata!'),
            duration: Duration(seconds: 2),
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

    final vm = Provider.of<PlacesViewModel>(context, listen: false);

    if (widget.placeToEdit != null) {
      final updated = widget.placeToEdit!.copyWith(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        radiusInMeters: _radiusInMeters,
        colorValue: _selectedColor.toARGB32(),
        notifyOnEntry: _notifyOnEntry,
        notifyOnExit: _notifyOnExit,
      );
      vm.updatePlace(updated);
    } else {
      final newPlace = Place(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        radiusInMeters: _radiusInMeters,
        colorValue: _selectedColor.toARGB32(),
        notifyOnEntry: _notifyOnEntry,
        notifyOnExit: _notifyOnExit,
      );
      vm.addPlace(newPlace);
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Luogo "${_nameController.text.trim()}" salvato con successo!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.placeToEdit != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tileUrl = isDark
        ? 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_selectedCategory.icon, color: _selectedColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? 'Modifica Luogo' : 'Nuovo Luogo',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Name field
                const Text(
                  'NOME DEL LUOGO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Es. Ufficio, Palestra McFit, Casa...',
                    prefixIcon: const Icon(Icons.edit_location_alt_rounded),
                    suffixIcon: _nameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _nameController.clear()),
                          )
                        : null,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Inserisci un nome per il luogo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Quick suggestions
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickSuggestions.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _nameController.text = s;
                              if (s == 'Ufficio' || s == 'Coworking') {
                                _selectedCategory = PlaceCategory.lavoro;
                              } else if (s == 'Palestra') {
                                _selectedCategory = PlaceCategory.palestra;
                              } else if (s == 'Casa') {
                                _selectedCategory = PlaceCategory.casa;
                              } else if (s == 'Studio') {
                                _selectedCategory = PlaceCategory.studio;
                              } else if (s == 'Bar preferito') {
                                _selectedCategory = PlaceCategory.svago;
                              }
                              _selectedColor = _selectedCategory.defaultColor;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // INTERACTIVE MAP PICKER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'POSIZIONE SU MAPPA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
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
                      label: Text(_isFetchingGps ? 'Rilevo...' : 'Mia Posizione GPS'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Map Container with visual pin and live geofence circle
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedPoint,
                          initialZoom: 15.5,
                          onTap: (_, point) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPoint = point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: tileUrl,
                            userAgentPackageName: 'com.tempo.app.tempo',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _selectedPoint,
                                radius: _radiusInMeters,
                                useRadiusInMeter: true,
                                color: _selectedColor.withValues(alpha: 0.25),
                                borderColor: _selectedColor,
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedPoint,
                                width: 44,
                                height: 44,
                                alignment: Alignment.topCenter,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _selectedColor.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _selectedCategory.icon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Tocca la mappa per spostare il pin',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Radius slider with live feedback
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RAGGIO DI RILEVAMENTO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _selectedColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_radiusInMeters.toInt()} metri',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
                  onChanged: (val) {
                    setState(() => _radiusInMeters = val);
                  },
                ),
                const SizedBox(height: 12),

                // Category selector
                const Text(
                  'CATEGORIA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
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
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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
                const SizedBox(height: 16),

                // Color picker
                const Text(
                  'COLORE IDENTIFICATIVO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _colorOptions.map((c) {
                    final isPicked = _selectedColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isPicked
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isPicked
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isPicked
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Notifications toggles
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Notifica all\'arrivo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Avvisa quando comincia il conteggio delle ore',
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Invia il riepilogo del tempo totale trascorso',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifyOnExit,
                  activeColor: _selectedColor,
                  onChanged: (v) => setState(() => _notifyOnExit = v),
                ),
                const SizedBox(height: 20),

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
                          elevation: 3,
                        ),
                        onPressed: _savePlace,
                        child: Text(
                          isEditing ? 'Aggiorna' : 'Salva Luogo',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
