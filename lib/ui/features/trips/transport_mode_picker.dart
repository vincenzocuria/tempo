import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/trip.dart';
import '../../core/app_colors.dart';

class TransportModePicker {
  static Future<String?> show(
    BuildContext context, {
    required String currentMode,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mezzo di Trasporto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Seleziona il mezzo con cui hai effettuato questo tragitto:',
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
                const SizedBox(height: 14),
                ...TransportMode.allModes.map((mode) {
                  final isSelected = mode.toLowerCase() == currentMode.toLowerCase() ||
                      (mode == TransportMode.auto && currentMode.toLowerCase().contains('auto')) ||
                      (mode == TransportMode.moto && currentMode.toLowerCase().contains('moto')) ||
                      (mode == TransportMode.bici && currentMode.toLowerCase().contains('bici')) ||
                      (mode == TransportMode.piedi && currentMode.toLowerCase().contains('piedi')) ||
                      (mode == TransportMode.corsa && currentMode.toLowerCase().contains('corsa'));

                  final icon = TransportMode.getIcon(mode);
                  final color = TransportMode.getColor(mode);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: isDark ? 0.18 : 0.1)
                          : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : borderColor,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(
                          mode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? color : textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: color)
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx, mode);
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
