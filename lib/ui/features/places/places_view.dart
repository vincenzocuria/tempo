import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/place.dart';
import '../../../data/services/tracking_engine.dart';
import '../../core/app_colors.dart';
import 'place_form_dialog.dart';
import 'places_view_model.dart';

class PlacesView extends StatelessWidget {
  const PlacesView({super.key});

  void _confirmDelete(BuildContext context, PlacesViewModel vm, Place place) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Luogo'),
        content: Text('Sei sicuro di voler eliminare "${place.name}"? Le visite storiche rimarranno registrate.'),
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
            onPressed: () {
              Navigator.pop(ctx);
              vm.deletePlace(place.id);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PlacesViewModel>(context);
    final trackingEngine = Provider.of<TrackingEngine>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('I Miei Luoghi'),
        actions: [
          IconButton(
            tooltip: 'Aggiungi luogo',
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const PlaceFormDialog(),
              );
            },
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.places.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Nessun luogo configurato',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aggiungi i tuoi posti abituali (es. Ufficio, Palestra, Casa) per tracciare automaticamente il tempo che ci passi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const PlaceFormDialog(),
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            'Aggiungi il Primo Luogo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: viewModel.places.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final place = viewModel.places[index];
                    final isCurrentPlace = trackingEngine.currentPlace?.id == place.id;
                    final totalTimeStr = viewModel.formatPlaceDuration(place.name);

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isCurrentPlace
                              ? place.color
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isCurrentPlace ? 2 : 1,
                        ),
                        boxShadow: isCurrentPlace
                            ? [
                                BoxShadow(
                                  color: place.color.withOpacity(0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: place.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: place.color.withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(
                                  place.icon,
                                  color: place.color,
                                  size: 24,
                                ),
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
                                            place.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCurrentPlace) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: place.color,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'SEI QUI',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      place.category.displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    showDialog(
                                      context: context,
                                      builder: (_) => PlaceFormDialog(placeToEdit: place),
                                    );
                                  } else if (action == 'delete') {
                                    _confirmDelete(context, viewModel, place);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Modifica'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            size: 18, color: AppColors.danger),
                                        SizedBox(width: 8),
                                        Text('Elimina',
                                            style: TextStyle(color: AppColors.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled_rounded,
                                      size: 16,
                                      color: AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Totale: $totalTimeStr',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.radar_rounded,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${place.radiusInMeters.toInt()}m',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Switch(
                                    value: place.isTrackingEnabled,
                                    activeColor: place.color,
                                    onChanged: (val) => viewModel.toggleTracking(place),
                                  ),
                                  Text(
                                    place.isTrackingEnabled
                                        ? 'Tracciamento attivo'
                                        : 'In pausa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: place.isTrackingEnabled
                                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isCurrentPlace)
                                TextButton.icon(
                                  onPressed: () => trackingEngine.manualCheckIn(place),
                                  icon: const Icon(Icons.touch_app_rounded, size: 16),
                                  label: const Text('Check-in ora'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const PlaceFormDialog(),
          );
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nuovo Luogo'),
      ),
    );
  }
}
