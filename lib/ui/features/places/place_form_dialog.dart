import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_category.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import '../categories/categories_view.dart';
import 'places_view_model.dart';

class PlaceFormDialog extends StatefulWidget {
  final Place? placeToEdit;
  final LatLng? initialLocation;

  const PlaceFormDialog({
    super.key,
    this.placeToEdit,
    this.initialLocation,
  });

  /// Opens the form as an ultra-modern modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    Place? placeToEdit,
    LatLng? initialLocation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaceFormDialog(
        placeToEdit: placeToEdit,
        initialLocation: initialLocation,
      ),
    );
  }

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
    Color(0xFF6366F1), // Indigo
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  final List<String> _quickSuggestions = [
    'Casa Principale',
    'Seconda Casa',
    'Ufficio Principale',
    'Secondo Lavoro',
    'Coworking',
    'Studio',
    'Casa al Mare',
    'Cliente / Cantiere',
    'Spesa & Servizi',
    'Sport & Benessere',
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
      // Default to last known position if available, else Rome coordinates as safe fallback
      LatLng fallbackPoint = const LatLng(41.9028, 12.4964);
      try {
        final engine = Provider.of<TrackingEngine>(context, listen: false);
        if (engine.lastKnownPosition != null) {
          fallbackPoint = LatLng(
            engine.lastKnownPosition!.latitude,
            engine.lastKnownPosition!.longitude,
          );
        }
      } catch (_) {}
      _selectedPoint = fallbackPoint;
      // Auto-fetch GPS silently
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentGps(showFeedback: false);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentGps({bool showFeedback = true}) async {
    setState(() => _isFetchingGps = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _selectedPoint = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_selectedPoint, 16.0);
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Posizione GPS agganciata!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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

    final messenger = ScaffoldMessenger.of(context);
    final placeName = _nameController.text.trim();
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Luogo "$placeName" salvato con successo!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.placeToEdit != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
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
                        color: _selectedColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_selectedCategory.icon, color: _selectedColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Modifica Luogo' : 'Nuovo Luogo',
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
                    backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    padding: const EdgeInsets.all(6),
                  ),
                  icon: Icon(Icons.close_rounded, size: 20, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Name Field
                    Text(
                      'NOME DEL LUOGO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Es. Casa Principale, Seconda Casa, Ufficio 2...',
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
                    const SizedBox(height: 10),

                    // Quick suggestions
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickSuggestions.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              side: BorderSide(color: borderColor),
                              label: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _nameController.text = s;
                                  if (s.contains('Seconda Casa') || s.contains('Casa al Mare')) {
                                    _selectedCategory = PlaceCategory.secondaCasa;
                                  } else if (s.contains('Casa')) {
                                    _selectedCategory = PlaceCategory.casa;
                                  } else if (s.contains('Secondo Lavoro') || s.contains('Coworking') || s.contains('Cliente')) {
                                    _selectedCategory = PlaceCategory.secondoLavoro;
                                  } else if (s.contains('Ufficio') || s.contains('Lavoro')) {
                                    _selectedCategory = PlaceCategory.lavoro;
                                  } else if (s.contains('Sport') || s.contains('Palestra')) {
                                    _selectedCategory = PlaceCategory.palestra;
                                  } else if (s.contains('Studio')) {
                                    _selectedCategory = PlaceCategory.studio;
                                  } else if (s.contains('Spesa') || s.contains('Servizi')) {
                                    _selectedCategory = PlaceCategory.servizi;
                                  } else {
                                    _selectedCategory = PlaceCategory.altro;
                                  }
                                  _selectedColor = _selectedCategory.defaultColor;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: INTERACTIVE MAP PICKER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'POSIZIONE SU MAPPA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: textMuted,
                          ),
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
                          label: Text(
                            _isFetchingGps ? 'Rilevo...' : 'Mia Posizione GPS',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

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
                          Positioned.fill(
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _selectedPoint,
                                initialZoom: 15.5,
                                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                onTap: (_, point) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedPoint = point);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  fallbackUrl: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName: 'com.tempo.app.tempo',
                                  maxZoom: 20,
                                  maxNativeZoom: 19,
                                  tileBuilder: isDark ? darkModeTileBuilder : null,
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
                                    'Tocca per spostare il pin',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _mapController.move(_selectedPoint, _mapController.camera.zoom + 1);
                                    },
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.add, size: 18, color: textPrimary),
                                    ),
                                  ),
                                  Divider(height: 1, thickness: 1, color: borderColor),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _mapController.move(_selectedPoint, _mapController.camera.zoom - 1);
                                    },
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.remove, size: 18, color: textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Radius slider with live feedback
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RAGGIO DI RILEVAMENTO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: textMuted,
                          ),
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
                    const SizedBox(height: 14),

                    // Section 4: Category selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CATEGORIA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: textMuted,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 15),
                          label: const Text(
                            'Gestisci Categorie',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CategoriesView()),
                            );
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final catRepo = Provider.of<CategoryRepository>(ctx);
                        final allCategories = catRepo.categories;

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...allCategories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return ChoiceChip(
                                selected: isSelected,
                                selectedColor: _selectedColor.withValues(alpha: 0.18),
                                backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                side: BorderSide(
                                  color: isSelected ? _selectedColor : borderColor,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cat.icon,
                                      size: 16,
                                      color: isSelected ? _selectedColor : cat.defaultColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat.displayName,
                                      style: TextStyle(
                                        color: isSelected ? _selectedColor : textPrimary,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
                            }),
                            ActionChip(
                              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              side: BorderSide(color: borderColor, style: BorderStyle.solid),
                              avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                              label: const Text(
                                'Crea Nuova',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CategoriesView()),
                                );
                                setState(() {});
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Section 5: Color picker
                    Text(
                      'COLORE IDENTIFICATIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _colorOptions.map((c) {
                        final isPicked = _selectedColor.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 36,
                            height: 36,
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
                    const SizedBox(height: 18),

                    // Section 6: Smart Notifications toggles (Card-grouped)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            title: Text(
                              'Notifica all\'arrivo',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                            subtitle: Text(
                              'Avvisa quando comincia il conteggio delle ore',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                            value: _notifyOnEntry,
                            activeColor: _selectedColor,
                            onChanged: (v) => setState(() => _notifyOnEntry = v),
                          ),
                          Divider(height: 1, color: borderColor),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            title: Text(
                              'Notifica alla partenza',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                            subtitle: Text(
                              'Invia il riepilogo del tempo totale trascorso',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                            value: _notifyOnExit,
                            activeColor: _selectedColor,
                            onChanged: (v) => setState(() => _notifyOnExit = v),
                          ),
                        ],
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
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
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _savePlace,
                            child: Text(
                              isEditing ? 'Aggiorna Luogo' : 'Salva Luogo',
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
        ],
      ),
    );
  }
}
