import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/permission_manager.dart';
import '../../core/app_colors.dart';

class OnboardingView extends StatefulWidget {
  final Widget? nextScreen;

  const OnboardingView({
    super.key,
    this.nextScreen,
  });

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isLocationGranted = false;
  bool _isBackgroundGranted = false;
  bool _isNotificationGranted = false;
  bool _isBatteryIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialPermissions();
    }
  }

  Future<void> _checkInitialPermissions() async {
    final status = await PermissionManager.instance.checkAllStatus();
    if (mounted) {
      setState(() {
        _isLocationGranted = status.locationGranted;
        _isBackgroundGranted = status.backgroundLocationGranted;
        _isNotificationGranted = status.notificationGranted;
        _isBatteryIgnored = status.batteryOptimizationIgnored;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;
    if (widget.nextScreen != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => widget.nextScreen!,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _runFullWizard() async {
    HapticFeedback.lightImpact();
    await PermissionManager.instance.runFullSetupWizard(context);
    await _checkInitialPermissions();
  }

  Future<void> _requestLocationPermission() async {
    HapticFeedback.lightImpact();
    await PermissionManager.instance.requestForegroundLocation();
    await _checkInitialPermissions();
  }

  Future<void> _requestBackgroundLocation() async {
    HapticFeedback.lightImpact();
    await PermissionManager.instance.requestBackgroundLocation(context);
    await _checkInitialPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    HapticFeedback.lightImpact();
    await PermissionManager.instance.requestNotifications();
    await _checkInitialPermissions();
  }

  Future<void> _requestBatteryOptimization() async {
    HapticFeedback.lightImpact();
    await PermissionManager.instance.requestBatteryOptimization();
    await _checkInitialPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF090D16)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                          ),
                          child: const Icon(Icons.timelapse_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TEMPO',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Salta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    // Slide 1: Welcome & Philosophy
                    _buildSlide(
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      badge: 'PRIVACY AL 100%',
                      badgeColor: AppColors.success,
                      title: 'Il tuo tempo nei luoghi che contano',
                      subtitle: 'Tempo monitora con precisione le tue soste a casa, a lavoro, in studio o nei tuoi posti abituali senza richiedere check-in manuali.',
                      iconWidget: _buildGlowingIcon(
                        icon: Icons.timer_outlined,
                        gradient: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      ),
                      features: const [
                        _FeatureRow(
                          icon: Icons.auto_mode_rounded,
                          title: 'Tracciamento Automatico',
                          description: 'L\'app capisce quando arrivi e quando parti in totale autonomia.',
                        ),
                        _FeatureRow(
                          icon: Icons.lock_outline_rounded,
                          title: '100% Locale sul Dispositivo',
                          description: 'Zero account, zero cloud, nessun dato esce mai dal tuo smartphone.',
                        ),
                      ],
                    ),

                    // Slide 2: Smart GPS & Comprehensive Android / Samsung Permissions
                    _buildSlide(
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      badge: 'CONFIGURAZIONE SAMSUNG & ANDROID',
                      badgeColor: AppColors.primary,
                      title: 'Autorizzazioni Essenziali',
                      subtitle: 'Per garantire che il conteggio funzioni anche a schermo spento, su Android e Samsung sono necessari questi permessi di sistema.',
                      iconWidget: _buildGlowingIcon(
                        icon: Icons.security_rounded,
                        gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      customBody: Column(
                        children: [
                          // 1-Tap Auto Setup Wizard Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _runFullWizard,
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                            label: const Text(
                              'Abilita Tutto con 1 Tocco',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _PermissionCard(
                            title: 'Posizione (In primo piano)',
                            subtitle: 'Per rilevare le coordinate dei tuoi luoghi',
                            isGranted: _isLocationGranted,
                            onTap: _requestLocationPermission,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _PermissionCard(
                            title: 'Posizione "Consenti sempre"',
                            subtitle: 'Consente il conteggio a schermo spento',
                            isGranted: _isBackgroundGranted,
                            onTap: _requestBackgroundLocation,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _PermissionCard(
                            title: 'Notifiche di Presenza',
                            subtitle: 'Avvisi discreti di arrivo e riepilogo durata',
                            isGranted: _isNotificationGranted,
                            onTap: _requestNotificationPermission,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _PermissionCard(
                            title: 'Nessuna Restrizione Batteria',
                            subtitle: 'Essenziale per Samsung / OneUI per non fermare l\'app',
                            isGranted: _isBatteryIgnored,
                            onTap: _requestBatteryOptimization,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),

                          TextButton.icon(
                            onPressed: () => PermissionManager.instance.openSystemSettings(),
                            icon: const Icon(Icons.settings_outlined, size: 15),
                            label: const Text(
                              'Apri Impostazioni App di Android',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Slide 3: Multi-Contexts & Habits
                    _buildSlide(
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      badge: 'FLESSIBILITÀ TOTALE',
                      badgeColor: const Color(0xFFF59E0B),
                      title: 'Più case, più lavori, zero schemi fissi',
                      subtitle: 'Nessuna categoria forzata: le statistiche si generano solo da dove vai veramente. L\'app impara i tuoi tragitti e ti suggerisce i posti frequenti.',
                      iconWidget: _buildGlowingIcon(
                        icon: Icons.hub_rounded,
                        gradient: const [Color(0xFFF59E0B), Color(0xFFEC4899)],
                      ),
                      features: const [
                        _FeatureRow(
                          icon: Icons.holiday_village_rounded,
                          title: 'Case e Lavori Multipli',
                          description: 'Gestisci Casa 1, Seconda Casa, Sede Principale, Coworking e Cantieri separatamente.',
                        ),
                        _FeatureRow(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Rilevamento Abitudini',
                          description: 'Se trascorri molto tempo in un posto abituale, l\'app ti proporrà di salvarlo con 1 tocco.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Navigation & Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Smooth Dots Indicator
                    Row(
                      children: List.generate(3, (index) {
                        final isSelected = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          height: 8,
                          width: isSelected ? 24 : 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (_currentPage < 2) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == 2 ? 'Inizia Ora' : 'Avanti',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == 2
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingIcon({
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 44),
    );
  }

  Widget _buildSlide({
    required bool isDark,
    required Color textPrimary,
    required Color textMuted,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required Widget iconWidget,
    List<Widget>? features,
    Widget? customBody,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 10),
          iconWidget,
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 18),
          ...?features,
          ?customBody,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
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
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onTap;
  final bool isDark;

  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? AppColors.success.withValues(alpha: 0.5) : borderColor,
          width: isGranted ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : Icons.shield_outlined,
              size: 18,
              color: isGranted ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isGranted
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary,
              foregroundColor: isGranted ? AppColors.success : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isGranted ? null : onTap,
            child: Text(
              isGranted ? 'Attivo' : 'Consenti',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isGranted ? AppColors.success : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
