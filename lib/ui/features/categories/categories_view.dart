import '../places/places_view_model.dart';
import '../../../data/services/tracking_engine.dart';
import '../analytics/analytics_view_model.dart';
import '../dashboard/dashboard_view_model.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/models/place_category.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/place_repository.dart';
import '../../core/app_colors.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  Map<String, int> _placeCountByCategory = {};
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadPlaceCounts();
  }

  Future<void> _loadPlaceCounts() async {
    final placeRepo = Provider.of<PlaceRepository>(context, listen: false);
    final places = await placeRepo.getAllPlaces();

    final counts = <String, int>{};
    for (final p in places) {
      final key = p.category.id;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _placeCountByCategory = counts;
        _isLoadingCounts = false;
      });
    }
  }

  void _showCategoryDialog({PlaceCategory? categoryToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(
        categoryToEdit: categoryToEdit,
        onSaved: () {
          _loadPlaceCounts();
        },
      ),
    );
  }

  void _confirmDeleteCategory(PlaceCategory cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textDarkPrimary
        : AppColors.textLightPrimary;
    final textMuted = isDark
        ? AppColors.textDarkMuted
        : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final placesCount = _placeCountByCategory[cat.id] ?? 0;

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
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Eliminare "${cat.displayName}"?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                placesCount > 0
                    ? 'Attenzione: ci sono $placesCount ${placesCount == 1 ? "luogo assegnato" : "luoghi assegnati"} a questa categoria. Verranno riassegnati alla categoria "Altro".'
                    : 'Questa categoria verrà eliminata definitivamente dalla lista.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 22),
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
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        final catRepo = Provider.of<CategoryRepository>(
                          context,
                          listen: false,
                        );
                        final placeRepo = Provider.of<PlaceRepository>(
                          context,
                          listen: false,
                        );
                        await catRepo.deleteCategory(
                          cat.id,
                          placeRepository: placeRepo,
                        );
                        if (!mounted) return;
                        await context.read<PlacesViewModel>().loadPlaces();
                        if (!mounted) return;
                        await context.read<TrackingEngine>().reloadActiveStateFromDb();
                        if (!mounted) return;
                        await context.read<AnalyticsViewModel>().loadAnalytics();
                        if (!mounted) return;
                        await context.read<DashboardViewModel>().loadData();
                        if (!mounted) return;
                        _loadPlaceCounts();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Categoria "${cat.displayName}" eliminata.',
                            ),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      },
                      child: const Text(
                        'Elimina',
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
    final catRepo = Provider.of<CategoryRepository>(context);
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

    final customCats = catRepo.customCategories;
    final defaultCats = catRepo.defaultCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Categorie'),
        actions: [
          IconButton(
            tooltip: 'Nuova Categoria',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // Informative banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFC7D2FE),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personalizza le Categorie',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Aggiungi e personalizza le categorie per classificare al meglio i tuoi luoghi e tracciare le statistiche.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // SECTION 1: Categorie Personalizzate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CATEGORIE PERSONALIZZATE (${customCats.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: textMuted,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Crea Nuova',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (customCats.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.label_outline_rounded,
                    size: 36,
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nessuna categoria personalizzata',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tocca "Crea Nuova" per aggiungere una categoria su misura con icona e colore dedicati.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...customCats.map((cat) => _buildCategoryTile(cat, isCustom: true)),

          const SizedBox(height: 24),

          // SECTION 2: Categorie Predefinite
          Text(
            'CATEGORIE PREDEFINITE DI SISTEMA (${defaultCats.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),

          ...defaultCats.map((cat) => _buildCategoryTile(cat, isCustom: false)),
          const SizedBox(height: 32),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nuova Categoria',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(PlaceCategory cat, {required bool isCustom}) {
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
    final placesCount = _placeCountByCategory[cat.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.defaultColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(cat.icon, color: cat.defaultColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cat.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isCustom
                                    ? AppColors.primary
                                    : const Color(0xFF64748B))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCustom ? 'Personalizzata' : 'Predefinita',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isCustom
                              ? AppColors.primary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _isLoadingCounts
                      ? 'Calcolo luoghi...'
                      : '$placesCount ${placesCount == 1 ? "luogo associato" : "luoghi associati"}',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          if (isCustom) ...[
            IconButton(
              tooltip: 'Modifica Categoria',
              icon: Icon(Icons.edit_outlined, size: 19, color: textMuted),
              onPressed: () => _showCategoryDialog(categoryToEdit: cat),
            ),
            IconButton(
              tooltip: 'Elimina Categoria',
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: AppColors.danger,
              ),
              onPressed: () => _confirmDeleteCategory(cat),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final PlaceCategory? categoryToEdit;
  final VoidCallback onSaved;

  const _CategoryFormSheet({this.categoryToEdit, required this.onSaved});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late IconData _selectedIcon;
  late Color _selectedColor;
  bool _isSaving = false;

  static const List<IconData> _availableIcons = [
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.local_cafe_rounded,
    Icons.restaurant_rounded,
    Icons.local_hospital_rounded,
    Icons.local_pharmacy_rounded,
    Icons.shopping_cart_rounded,
    Icons.storefront_rounded,
    Icons.fitness_center_rounded,
    Icons.pool_rounded,
    Icons.sports_soccer_rounded,
    Icons.sports_tennis_rounded,
    Icons.park_rounded,
    Icons.beach_access_rounded,
    Icons.cabin_rounded,
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.business_center_rounded,
    Icons.handshake_rounded,
    Icons.child_care_rounded,
    Icons.family_restroom_rounded,
    Icons.pets_rounded,
    Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
    Icons.flight_takeoff_rounded,
    Icons.music_note_rounded,
    Icons.movie_rounded,
    Icons.palette_rounded,
    Icons.church_rounded,
    Icons.construction_rounded,
    Icons.apartment_rounded,
    Icons.weekend_rounded,
    Icons.home_work_rounded,
    Icons.work_outline_rounded,
    Icons.science_rounded,
  ];

  static const List<Color> _availableColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF3B82F6), // Blue
    Color(0xFF0284C7), // Sky
    Color(0xFF06B6D4), // Cyan
    Color(0xFF14B8A6), // Teal
    Color(0xFF10B981), // Emerald
    Color(0xFF84CC16), // Lime
    Color(0xFFF59E0B), // Amber
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFFA855F7), // Purple
    Color(0xFF78716C), // Stone
    Color(0xFF64748B), // Slate
    Color(0xFF0D9488), // Deep Teal
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.categoryToEdit;
    _nameController = TextEditingController(text: c?.displayName ?? '');
    _selectedIcon = c?.icon ?? _availableIcons.first;
    _selectedColor = c?.defaultColor ?? _availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final catRepo = Provider.of<CategoryRepository>(context, listen: false);
    final name = _nameController.text.trim();

    try {
      if (widget.categoryToEdit != null) {
        final updated = widget.categoryToEdit!.copyWith(
          displayName: name,
          icon: _selectedIcon,
          defaultColor: _selectedColor,
        );
        await catRepo.updateCategory(updated);
      } else {
        await catRepo.addCategory(
          displayName: name,
          icon: _selectedIcon,
          color: _selectedColor,
        );
      }

      HapticFeedback.mediumImpact();
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Categoria "$name" salvata con successo!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel salvataggio: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.categoryToEdit != null;
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
    final elevatedBg = isDark
        ? AppColors.darkSurfaceElevated
        : AppColors.lightSurfaceElevated;

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
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedIcon,
                        color: _selectedColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Modifica Categoria' : 'Nuova Categoria',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
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
                    // Live Preview Chip
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedIcon,
                              color: _selectedColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _nameController.text.trim().isNotEmpty
                                  ? _nameController.text.trim()
                                  : 'Anteprima Categoria',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _selectedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 1: Category Name
                    Text(
                      'NOME DELLA CATEGORIA',
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
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Es. Scuola, Volontariato, Ristorante, Famiglia...',
                        prefixIcon: Icon(Icons.label_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Inserisci un nome per la categoria';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Icon Picker
                    Text(
                      'SCEGLI UN\'ICONA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 150,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: elevatedBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _availableIcons.length,
                        itemBuilder: (ctx, idx) {
                          final icon = _availableIcons[idx];
                          final isSelected = _selectedIcon == icon;
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedIcon = icon);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isSelected ? _selectedColor : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? _selectedColor
                                      : borderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? Colors.white : textPrimary,
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Color Picker
                    Text(
                      'COLORE DISTINTIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableColors.map((color) {
                        final isSelected = _selectedColor == color;
                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = color);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          _isSaving
                              ? 'Salvataggio...'
                              : (isEditing
                                    ? 'Salva Modifiche'
                                    : 'Crea Categoria'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
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
