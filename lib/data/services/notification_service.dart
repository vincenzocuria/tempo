import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_notification.dart';
import 'database_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _dbService;

  bool _isInitialized = false;
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  NotificationService._init({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    _isInitialized = true;
    await refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _dbService.getUnreadNotificationCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final bool? granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }
    return true;
  }

  Future<void> showPlaceEntryNotification({
    required String placeName,
    required String categoryName,
  }) async {
    if (!_isInitialized) await initialize();

    final notif = AppNotification(
      title: 'Sei arrivato a $placeName',
      body: 'Monitoraggio del tempo avviato per $categoryName.',
      type: NotificationType.entry,
      payload: placeName,
    );
    try {
      await _dbService.insertNotification(notif);
      _unreadCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'tempo_places_channel',
      'Presenza Luoghi',
      channelDescription: 'Notifiche di arrivo e partenza dai luoghi tracciati',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 1001,
        title: notif.title,
        body: notif.body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing entry notification: $e');
    }
  }

  Future<void> showPlaceExitNotification({
    required String placeName,
    required String formattedDuration,
  }) async {
    if (!_isInitialized) await initialize();

    final notif = AppNotification(
      title: 'Uscito da $placeName',
      body: 'Hai trascorso $formattedDuration in questo luogo.',
      type: NotificationType.exit,
      payload: placeName,
    );
    try {
      await _dbService.insertNotification(notif);
      _unreadCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'tempo_places_channel',
      'Presenza Luoghi',
      channelDescription: 'Notifiche di arrivo e partenza dai luoghi tracciati',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 1002,
        title: notif.title,
        body: notif.body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing exit notification: $e');
    }
  }

  Future<void> showAreaExitAndTripStartedNotification({
    required String placeName,
    String? formattedDuration,
  }) async {
    if (!_isInitialized) await initialize();

    final bodyText = formattedDuration != null
        ? 'Hai trascorso $formattedDuration qui. Tragitto avviato in background.'
        : 'Sei uscito dall\'area. Registrazione spostamento avviata.';

    final notif = AppNotification(
      title: '🚶 Uscito da $placeName',
      body: bodyText,
      type: NotificationType.exit,
      payload: placeName,
    );
    try {
      await _dbService.insertNotification(notif);
      _unreadCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'tempo_places_channel',
      'Presenza e Spostamenti',
      channelDescription: 'Notifiche di entrata/uscita area e registrazione tragitti',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 1002,
        title: notif.title,
        body: notif.body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing area exit notification: $e');
    }
  }

  Future<void> showTripCompletedNotification({
    required String destinationName,
    required String formattedDistance,
    required String formattedDuration,
    String? originName,
  }) async {
    if (!_isInitialized) await initialize();

    final title = '📍 Arrivato a $destinationName';
    final body = originName != null
        ? 'Tragitto da $originName: $formattedDistance in $formattedDuration.'
        : 'Tragitto completato: $formattedDistance in $formattedDuration.';

    final notif = AppNotification(
      title: title,
      body: body,
      type: NotificationType.trip,
      payload: destinationName,
    );
    try {
      await _dbService.insertNotification(notif);
      _unreadCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'tempo_places_channel',
      'Presenza e Spostamenti',
      channelDescription: 'Notifiche di entrata/uscita area e registrazione tragitti',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 1001,
        title: notif.title,
        body: notif.body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing trip completion notification: $e');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 1003,
    NotificationType type = NotificationType.habit,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    final notif = AppNotification(
      title: title,
      body: body,
      type: type,
      payload: payload,
    );
    try {
      await _dbService.insertNotification(notif);
      _unreadCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'tempo_habits_channel',
      'Luoghi e Abitudini',
      channelDescription: 'Suggerimenti su soste prolungate e luoghi frequenti',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // --- REGISTRO NOTIFICHE (NOTIFICATION LOG API) ---

  Future<List<AppNotification>> getNotificationLog({int limit = 100, int offset = 0}) async {
    return await _dbService.getNotifications(limit: limit, offset: offset);
  }

  Future<void> markAsRead(String id) async {
    await _dbService.markNotificationAsRead(id);
    await refreshUnreadCount();
  }

  Future<void> markAllAsRead() async {
    await _dbService.markAllNotificationsAsRead();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _dbService.deleteNotification(id);
    await refreshUnreadCount();
  }

  Future<void> clearAll() async {
    await _dbService.clearAllNotifications();
    _unreadCount = 0;
    notifyListeners();
  }
}
