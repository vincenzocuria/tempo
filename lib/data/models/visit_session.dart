import 'package:uuid/uuid.dart';

import 'place_category.dart';

const _unset = Object();

class VisitSession {
  final String id;
  final String placeId;
  final String placeName;
  final PlaceCategory category;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isManual;
  final String? notes;

  VisitSession({
    String? id,
    required this.placeId,
    required this.placeName,
    required this.category,
    required this.startTime,
    this.endTime,
    int? durationSeconds,
    this.isManual = false,
    this.notes,
  }) : id = id ?? const Uuid().v4(),
       durationSeconds =
           durationSeconds ??
           (endTime != null ? endTime.difference(startTime).inSeconds : 0);

  bool get isOngoing => endTime == null;

  Duration get currentDuration {
    if (endTime != null) {
      return Duration(seconds: durationSeconds);
    }
    final now = DateTime.now();
    return now.isAfter(startTime) ? now.difference(startTime) : Duration.zero;
  }

  String get formattedDuration {
    final dur = currentDuration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${dur.inSeconds}s';
  }

  VisitSession copyWith({
    String? id,
    String? placeId,
    String? placeName,
    PlaceCategory? category,
    DateTime? startTime,
    Object? endTime = _unset,
    int? durationSeconds,
    bool? isManual,
    Object? notes = _unset,
  }) {
    return VisitSession(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: identical(endTime, _unset) ? this.endTime : endTime as DateTime?,
      durationSeconds:
          durationSeconds ??
          (startTime != null || !identical(endTime, _unset)
              ? null
              : this.durationSeconds),
      isManual: isManual ?? this.isManual,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placeId': placeId,
      'placeName': placeName,
      'category': category.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'isManual': isManual ? 1 : 0,
      'notes': notes,
    };
  }

  factory VisitSession.fromMap(Map<String, dynamic> map) {
    final start = DateTime.parse(map['startTime'] as String);
    final endStr = map['endTime'] as String?;
    final end = endStr != null ? DateTime.tryParse(endStr) : null;
    final durSec =
        map['durationSeconds'] as int? ??
        (end != null ? end.difference(start).inSeconds : 0);

    return VisitSession(
      id: map['id'] as String,
      placeId: map['placeId'] as String,
      placeName: map['placeName'] as String,
      category: PlaceCategory.fromString(map['category'] as String?),
      startTime: start,
      endTime: end,
      durationSeconds: durSec,
      isManual: (map['isManual'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
    );
  }
}
