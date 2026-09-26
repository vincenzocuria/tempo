import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class TripPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed; // in m/s

  TripPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      't': timestamp.toIso8601String(),
      if (speed != null) 's': speed,
    };
  }

  factory TripPoint.fromMap(Map<String, dynamic> map) {
    return TripPoint(
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      timestamp: DateTime.tryParse(map['t'] as String? ?? '') ?? DateTime.now(),
      speed: (map['s'] as num?)?.toDouble(),
    );
  }
}

class Trip {
  final String id;
  final String? originPlaceId;
  final String originPlaceName;
  final String? destinationPlaceId;
  final String? destinationPlaceName;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final double distanceMeters;
  final String transportMode;
  final List<TripPoint> routePoints;
  final String? notes;

  Trip({
    String? id,
    this.originPlaceId,
    required this.originPlaceName,
    this.destinationPlaceId,
    this.destinationPlaceName,
    required this.startTime,
    this.endTime,
    int? durationSeconds,
    this.distanceMeters = 0.0,
    this.transportMode = 'In spostamento',
    List<TripPoint>? routePoints,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        routePoints = routePoints ?? [],
        durationSeconds = durationSeconds ??
            (endTime != null
                ? endTime.difference(startTime).inSeconds
                : 0);

  bool get isOngoing => endTime == null;

  Duration get currentDuration {
    if (endTime != null) {
      return Duration(seconds: durationSeconds);
    }
    final now = DateTime.now();
    return now.isAfter(startTime)
        ? now.difference(startTime)
        : Duration.zero;
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

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  double get averageSpeedKmH {
    final dur = currentDuration;
    if (dur.inSeconds < 10 || distanceMeters < 10) return 0.0;
    final hours = dur.inSeconds / 3600.0;
    return (distanceMeters / 1000.0) / hours;
  }

  List<LatLng> get latLngPoints {
    return routePoints.map((p) => p.toLatLng()).toList();
  }

  Trip copyWith({
    String? id,
    String? originPlaceId,
    String? originPlaceName,
    String? destinationPlaceId,
    String? destinationPlaceName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? distanceMeters,
    String? transportMode,
    List<TripPoint>? routePoints,
    String? notes,
  }) {
    return Trip(
      id: id ?? this.id,
      originPlaceId: originPlaceId ?? this.originPlaceId,
      originPlaceName: originPlaceName ?? this.originPlaceName,
      destinationPlaceId: destinationPlaceId ?? this.destinationPlaceId,
      destinationPlaceName: destinationPlaceName ?? this.destinationPlaceName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      transportMode: transportMode ?? this.transportMode,
      routePoints: routePoints ?? this.routePoints,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    final encodedPoints = jsonEncode(routePoints.map((p) => p.toMap()).toList());
    return {
      'id': id,
      'originPlaceId': originPlaceId,
      'originPlaceName': originPlaceName,
      'destinationPlaceId': destinationPlaceId,
      'destinationPlaceName': destinationPlaceName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'transportMode': transportMode,
      'encodedPoints': encodedPoints,
      'notes': notes,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    final start = DateTime.parse(map['startTime'] as String);
    final endStr = map['endTime'] as String?;
    final end = endStr != null ? DateTime.tryParse(endStr) : null;

    List<TripPoint> points = [];
    final rawPoints = map['encodedPoints'] as String?;
    if (rawPoints != null && rawPoints.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPoints) as List<dynamic>;
        points = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => TripPoint.fromMap(item))
            .toList();
      } catch (_) {}
    }

    return Trip(
      id: map['id'] as String,
      originPlaceId: map['originPlaceId'] as String?,
      originPlaceName: map['originPlaceName'] as String? ?? 'Origine',
      destinationPlaceId: map['destinationPlaceId'] as String?,
      destinationPlaceName: map['destinationPlaceName'] as String?,
      startTime: start,
      endTime: end,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      transportMode: map['transportMode'] as String? ?? 'In spostamento',
      routePoints: points,
      notes: map['notes'] as String?,
    );
  }
}
