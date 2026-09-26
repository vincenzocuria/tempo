import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/services/notification_service.dart';
import '../../core/app_colors.dart';

class NotificationLogSheet extends StatefulWidget {
  final bool isDark;

  const NotificationLogSheet({
    super.key,
    required this.isDark,
  });

  static Future<void> show(BuildContext context, {required bool isDark}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationLogSheet(isDark: isDark),
    );
  }

  @override
  State<NotificationLogSheet> createState() => _NotificationLogSheetState();
}

class _NotificationLogSheetState extends State<NotificationLogSheet> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationService.instance.getNotificationLog();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.selectionClick();
    await NotificationService.instance.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _clearAll() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancella Registro Notifiche'),
        content: const Text(
          'Sei sicuro di voler eliminare tutte le notifiche salvate? Questa operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancella tutto'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService.instance.clearAll();
      await _loadNotifications();
    }
  }

  Future<void> _onItemTap(AppNotification notif) async {
    if (!notif.isRead) {
      HapticFeedback.selectionClick();
      await NotificationService.instance.markAsRead(notif.id);
      await _loadNotifications();
    }
  }

  Future<void> _deleteItem(String id) async {
    HapticFeedback.lightImpact();
    await NotificationService.instance.deleteNotification(id);
    await _loadNotifications();
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.entry:
        return const Color(0xFF10B981); // Emerald green
      case NotificationType.exit:
        return const Color(0xFFF59E0B); // Amber / orange
      case NotificationType.trip:
        return const Color(0xFF0EA5E9); // Sky blue
      case NotificationType.habit:
        return const Color(0xFF8B5CF6); // Violet / purple
      case NotificationType.system:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.entry:
        return Icons.login_rounded;
      case NotificationType.exit:
        return Icons.logout_rounded;
      case NotificationType.trip:
        return Icons.navigation_rounded;
      case NotificationType.habit:
        return Icons.auto_awesome_rounded;
      case NotificationType.system:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Registro Notifiche',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unreadCount nuove',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Storico permanente di arrivi, partenze e abitudini',
                            style: TextStyle(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Actions Row (Mark all read, clear)
              if (_notifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (unreadCount > 0)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('Segna tutte come lette', style: TextStyle(fontSize: 12)),
                        )
                      else
                        Text(
                          '${_notifications.length} notifiche archiviate',
                          style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600),
                        ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _clearAll,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: const Text('Svuota', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                        ? _buildEmptyState(isDark, textPrimary, textMuted)
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              return _buildNotificationCard(
                                notif: notif,
                                isDark: isDark,
                                textPrimary: textPrimary,
                                textMuted: textMuted,
                                borderColor: borderColor,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, Color textPrimary, Color textMuted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna notifica registrata',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tutte le notifiche push di arrivi, uscite, spostamenti e abitudini rilevate vengono conservate qui automaticamente, anche se le cancelli dal centro notifiche di sistema.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required AppNotification notif,
    required bool isDark,
    required Color textPrimary,
    required Color textMuted,
    required Color borderColor,
  }) {
    final typeColor = _getTypeColor(notif.type);
    final typeIcon = _getTypeIcon(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(notif.id),
      child: InkWell(
        onTap: () => _onItemTap(notif),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? (isDark ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5) : const Color(0xFFF8FAFC))
                : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notif.isRead ? borderColor : typeColor.withValues(alpha: 0.5),
              width: notif.isRead ? 1.0 : 1.5,
            ),
            boxShadow: notif.isRead
                ? null
                : [
                    BoxShadow(
                      color: typeColor.withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title, Body, Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notif.type.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          notif.timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: notif.isRead ? textMuted : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),

              // Unread Blue Dot
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
