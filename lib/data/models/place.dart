import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'place_category.dart';

class Place {
  final String id;
  final String name;
  final PlaceCategory category;
  final double latitude;
  final double longitude;
  final double radiusInMeters;
  final int colorValue;
  final int iconCodePoint;
  final bool notifyOnEntry;
  final bool notifyOnExit;
  final bool isTrackingEnabled;
  final DateTime createdAt;

  Place({
    String? id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.radiusInMeters = 100.0,
    int? colorValue,
    int? iconCodePoint,
    this.notifyOnEntry = true,
    this.notifyOnExit = true,
    this.isTrackingEnabled = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        colorValue = colorValue ?? category.defaultColor.value,
        iconCodePoint = iconCodePoint ?? category.icon.codePoint,
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  IconData get icon => category.icon;

  Place copyWith({
    String? id,
    String? name,
    PlaceCategory? category,
    double? latitude,
    double? longitude,
    double? radiusInMeters,
    int? colorValue,
    int? iconCodePoint,
    bool? notifyOnEntry,
    bool? notifyOnExit,
    bool? isTrackingEnabled,
    DateTime? createdAt,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      notifyOnEntry: notifyOnEntry ?? this.notifyOnEntry,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
      isTrackingEnabled: isTrackingEnabled ?? this.isTrackingEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusInMeters': radiusInMeters,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'notifyOnEntry': notifyOnEntry ? 1 : 0,
      'notifyOnExit': notifyOnExit ? 1 : 0,
      'isTrackingEnabled': isTrackingEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id'] as String,
      name: map['name'] as String,
      category: PlaceCategory.fromString(map['category'] as String?),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusInMeters: (map['radiusInMeters'] as num?)?.toDouble() ?? 100.0,
      colorValue: map['colorValue'] as int?,
      iconCodePoint: map['iconCodePoint'] as int?,
      notifyOnEntry: (map['notifyOnEntry'] as int? ?? 1) == 1,
      notifyOnExit: (map['notifyOnExit'] as int? ?? 1) == 1,
      isTrackingEnabled: (map['isTrackingEnabled'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
