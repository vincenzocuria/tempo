import 'package:uuid/uuid.dart';
import 'place_category.dart';

enum HabitStatus {
  learning,  // In fase di apprendimento/osservazione silenziosa (non ancora proposta)
  pending,   // Abitudine confermata (visite ricorrenti in giorni diversi): proposta all'utente
  saved,     // Salvata come luogo registrato
  dismissed; // Ignorata/rifiutata dall'utente

  static HabitStatus fromString(String? val) {
    if (val == null) return HabitStatus.learning;
    return HabitStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => HabitStatus.learning,
    );
  }
}

class HabitSuggestion {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime firstDetected;
  final DateTime lastDetected;
  final int visitCount;
  final int totalMinutesSpent;
  final String? suggestedName;
  final PlaceCategory suggestedCategory;
  final HabitStatus status;

  HabitSuggestion({
    String? id,
    required this.latitude,
    required this.longitude,
    DateTime? firstDetected,
    DateTime? lastDetected,
    this.visitCount = 1,
    this.totalMinutesSpent = 0,
    this.suggestedName,
    this.suggestedCategory = PlaceCategory.altro,
    this.status = HabitStatus.pending,
  })  : id = id ?? const Uuid().v4(),
        firstDetected = firstDetected ?? DateTime.now(),
        lastDetected = lastDetected ?? DateTime.now();

  HabitSuggestion copyWith({
    String? id,
    double? latitude,
    double? longitude,
    DateTime? firstDetected,
    DateTime? lastDetected,
    int? visitCount,
    int? totalMinutesSpent,
    String? suggestedName,
    PlaceCategory? suggestedCategory,
    HabitStatus? status,
  }) {
    return HabitSuggestion(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      firstDetected: firstDetected ?? this.firstDetected,
      lastDetected: lastDetected ?? this.lastDetected,
      visitCount: visitCount ?? this.visitCount,
      totalMinutesSpent: totalMinutesSpent ?? this.totalMinutesSpent,
      suggestedName: suggestedName ?? this.suggestedName,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'firstDetected': firstDetected.toIso8601String(),
      'lastDetected': lastDetected.toIso8601String(),
      'visitCount': visitCount,
      'totalMinutesSpent': totalMinutesSpent,
      'suggestedName': suggestedName,
      'suggestedCategory': suggestedCategory.name,
      'status': status.name,
    };
  }

  factory HabitSuggestion.fromMap(Map<String, dynamic> map) {
    return HabitSuggestion(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      firstDetected: DateTime.tryParse(map['firstDetected'] as String? ?? '') ?? DateTime.now(),
      lastDetected: DateTime.tryParse(map['lastDetected'] as String? ?? '') ?? DateTime.now(),
      visitCount: map['visitCount'] as int? ?? 1,
      totalMinutesSpent: map['totalMinutesSpent'] as int? ?? 0,
      suggestedName: map['suggestedName'] as String?,
      suggestedCategory: PlaceCategory.fromString(map['suggestedCategory'] as String?),
      status: HabitStatus.fromString(map['status'] as String?),
    );
  }

  String get formattedDuration {
    final hours = totalMinutesSpent ~/ 60;
    final mins = totalMinutesSpent % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// True solo quando il luogo presenta una reale ricorrenza abituale
  bool get isHabit => visitCount >= 3 && totalMinutesSpent >= 45;
}
