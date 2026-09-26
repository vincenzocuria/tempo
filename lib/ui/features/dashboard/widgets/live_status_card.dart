import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../data/services/tracking_engine.dart';
import '../../../core/app_colors.dart';

class LiveStatusCard extends StatefulWidget {
  final TrackingEngine trackingEngine;
  final VoidCallback onQuickCheckInTap;

  const LiveStatusCard({
    super.key,
    required this.trackingEngine,
    required this.onQuickCheckInTap,
  });

  @override
  State<LiveStatusCard> createState() => _LiveStatusCardState();
}

class _LiveStatusCardState extends State<LiveStatusCard>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTimer(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.trackingEngine;
    final activeVisit = engine.activeVisit;
    final currentPlace = engine.currentPlace;
    final isInside = activeVisit != null && currentPlace != null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isInside ? currentPlace.color : AppColors.primary;

    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardElevatedBg = isDark ? AppColors.darkSurfaceElevated : Colors.white;

    final timeFormatter = DateFormat('HH:mm');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isInside
              ? [
                  currentPlace.color.withValues(alpha: isDark ? 0.22 : 0.14),
                  currentPlace.color.withValues(alpha: isDark ? 0.05 : 0.02),
                ]
              : [
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  isDark ? const Color(0xFF0F172A) : Colors.white,
                ],
        ),
        border: Border.all(
          color: isInside
              ? currentPlace.color.withValues(alpha: 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isInside ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isInside ? currentPlace.color : Colors.black).withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Status Indicator & GPS Refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isInside)
                          AnimatedBuilder(
                            animation: _rippleController,
                            builder: (context, _) {
                              final progress = _rippleController.value;
                              return Container(
                                width: 22 * progress,
                                height: 22 * progress,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0)),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            return Transform.scale(
                              scale: isInside ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isInside ? accentColor : const Color(0xFF94A3B8),
                                  boxShadow: isInside
                                      ? [
                                          BoxShadow(
                                            color: accentColor.withValues(alpha: 0.7),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isInside ? 'PRESENZA ATTIVA' : 'IN MOVIMENTO / FUORI ZONA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isInside ? accentColor : textMuted,
                    ),
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                ),
                icon: engine.isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, size: 20, color: textMuted),
                tooltip: 'Rileva coordinate GPS',
                onPressed: engine.isChecking
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        engine.checkCurrentLocation();
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inside Place State
          if (isInside) ...[
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: currentPlace.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: currentPlace.color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentPlace.color.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    currentPlace.icon,
                    color: currentPlace.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPlace.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: currentPlace.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: currentPlace.color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              currentPlace.category.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: currentPlace.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Arrivo alle ${timeFormatter.format(activeVisit.startTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: cardElevatedBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            size: 13,
                            color: textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DURATA SOSTA ATTUALE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimer(activeVisit.currentDuration),
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                          color: currentPlace.color,
                          shadows: [
                            Shadow(
                              color: currentPlace.color.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      foregroundColor: AppColors.danger,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      engine.manualCheckOut();
                    },
                    icon: const Icon(Icons.exit_to_app_rounded, size: 17),
                    label: const Text(
                      'Check-out',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Outside / Moving State
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nessuna sosta attiva',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        engine.statusMessage ??
                            'In attesa di raggiungere un luogo registrato.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      engine.checkCurrentLocation();
                    },
                    icon: const Icon(Icons.gps_fixed_rounded, size: 17),
                    label: Text(
                      'Rileva Ora',
                      style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onQuickCheckInTap();
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 17),
                    label: Text(
                      'Check-in',
                      style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
