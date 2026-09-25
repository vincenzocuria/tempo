import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Continuous radiating radar ripple
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Subtle scale heartbeat
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isInside
              ? [
                  currentPlace.color.withValues(alpha: isDark ? 0.22 : 0.15),
                  currentPlace.color.withValues(alpha: isDark ? 0.06 : 0.03),
                ]
              : [
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
            color: (isInside ? currentPlace.color : Colors.black).withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Dual-ring living radar animation
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isInside) ...[
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
                        ],
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
                    isInside ? 'PRESENZA RILEVATA' : 'STATO ATTUALE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isInside
                          ? accentColor
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: engine.isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Aggiorna coordinate GPS',
                onPressed: engine.isChecking
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        engine.checkCurrentLocation();
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isInside) ...[
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: currentPlace.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: currentPlace.color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentPlace.color.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    currentPlace.icon,
                    color: currentPlace.color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPlace.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: currentPlace.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: currentPlace.color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          currentPlace.category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: currentPlace.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                            Icons.timer_outlined,
                            size: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'TEMPO TRASCORSO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimer(activeVisit.currentDuration),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                          color: currentPlace.color,
                          shadows: [
                            Shadow(
                              color: currentPlace.color.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      engine.manualCheckOut();
                    },
                    icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                    label: const Text(
                      'Check-out',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFF94A3B8),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'In movimento / Fuori zona',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        engine.statusMessage ??
                            'Nessun luogo registrato nelle vicinanze.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      engine.checkCurrentLocation();
                    },
                    icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                    label: const Text('Rileva Ora', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onQuickCheckInTap();
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 18),
                    label: const Text('Check-in', style: TextStyle(fontWeight: FontWeight.w700)),
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
