import 'package:uuid/uuid.dart';

enum NotificationType {
  entry,   // Arrivo in un luogo
  exit,    // Uscita da un luogo
  trip,    // Percorso / Spostamento
  habit,   // Abitudine rilevata
  system;  // Notifica di sistema

  static NotificationType fromString(String? val) {
    if (val == null) return NotificationType.system;
    return NotificationType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => NotificationType.system,
    );
  }

  String get displayName {
    switch (this) {
      case NotificationType.entry:
        return 'Arrivo';
      case NotificationType.exit:
        return 'Partenza';
      case NotificationType.trip:
        return 'Spostamento';
      case NotificationType.habit:
        return 'Abitudine';
      case NotificationType.system:
        return 'Sistema';
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? payload;

  AppNotification({
    String? id,
    required this.title,
    required this.body,
    required this.type,
    DateTime? timestamp,
    this.isRead = false,
    this.payload,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? payload,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
      'payload': payload,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: NotificationType.fromString(map['type'] as String?),
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      isRead: (map['isRead'] as int? ?? 0) == 1,
      payload: map['payload'] as String?,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Proprio ora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m fa';
    if (diff.inHours < 24) return '${diff.inHours}h fa';
    if (diff.inDays == 1) return 'Ieri';
    return '${diff.inDays}g fa';
  }
}
