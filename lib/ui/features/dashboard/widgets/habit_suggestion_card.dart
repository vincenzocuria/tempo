import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../data/models/habit_suggestion.dart';
import '../../../../data/services/habit_detection_service.dart';
import '../../../core/app_colors.dart';
import '../../places/place_form_dialog.dart';

class HabitSuggestionCard extends StatelessWidget {
  final HabitSuggestion suggestion;
  final VoidCallback onDismissed;
  final VoidCallback onSaved;

  const HabitSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onDismissed,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurfaceElevated : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LUOGO ABITUALE RILEVATO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sosta frequente (${suggestion.formattedDuration})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: textMuted),
                tooltip: 'Ignora suggerimento',
                onPressed: () async {
                  await HabitDetectionService.instance.dismissSuggestion(suggestion.id);
                  onDismissed();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Hai trascorso del tempo in questa posizione (${suggestion.visitCount} ${suggestion.visitCount == 1 ? "sosta" : "soste"}). Vuoi salvarla tra i tuoi luoghi (es. Seconda Casa, Ufficio, Studio)?',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await PlaceFormDialog.show(
                      context,
                      initialLocation: LatLng(suggestion.latitude, suggestion.longitude),
                    );
                    await HabitDetectionService.instance.markSaved(suggestion.id);
                    onSaved();
                  },
                  icon: const Icon(Icons.bookmark_add_rounded, size: 17),
                  label: const Text(
                    'Salva nei Luoghi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                onPressed: () async {
                  await HabitDetectionService.instance.dismissSuggestion(suggestion.id);
                  onDismissed();
                },
                child: const Text(
                  'Non ora',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
