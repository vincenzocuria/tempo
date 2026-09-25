import 'package:flutter/material.dart';

enum PlaceCategory {
  lavoro,
  palestra,
  casa,
  studio,
  svago,
  altro;

  String get displayName {
    switch (this) {
      case PlaceCategory.lavoro:
        return 'Lavoro';
      case PlaceCategory.palestra:
        return 'Palestra & Sport';
      case PlaceCategory.casa:
        return 'Casa';
      case PlaceCategory.studio:
        return 'Studio & Università';
      case PlaceCategory.svago:
        return 'Svago & Tempo Libero';
      case PlaceCategory.altro:
        return 'Altro';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.lavoro:
        return Icons.business_center_rounded;
      case PlaceCategory.palestra:
        return Icons.fitness_center_rounded;
      case PlaceCategory.casa:
        return Icons.home_rounded;
      case PlaceCategory.studio:
        return Icons.school_rounded;
      case PlaceCategory.svago:
        return Icons.coffee_rounded;
      case PlaceCategory.altro:
        return Icons.location_on_rounded;
    }
  }

  Color get defaultColor {
    switch (this) {
      case PlaceCategory.lavoro:
        return const Color(0xFF3B82F6); // Blue
      case PlaceCategory.palestra:
        return const Color(0xFF10B981); // Emerald
      case PlaceCategory.casa:
        return const Color(0xFFF59E0B); // Amber
      case PlaceCategory.studio:
        return const Color(0xFF8B5CF6); // Violet
      case PlaceCategory.svago:
        return const Color(0xFFEC4899); // Pink
      case PlaceCategory.altro:
        return const Color(0xFF64748B); // Slate
    }
  }

  static PlaceCategory fromString(String? val) {
    if (val == null) return PlaceCategory.altro;
    return PlaceCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => PlaceCategory.altro,
    );
  }
}
