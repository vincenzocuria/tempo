import 'package:flutter/material.dart';

enum PlaceCategory {
  casa,
  secondaCasa,
  lavoro,
  secondoLavoro,
  studio,
  palestra,
  svago,
  servizi,
  altro;

  String get displayName {
    switch (this) {
      case PlaceCategory.casa:
        return 'Casa';
      case PlaceCategory.secondaCasa:
        return 'Seconda Casa';
      case PlaceCategory.lavoro:
        return 'Lavoro';
      case PlaceCategory.secondoLavoro:
        return 'Secondo Lavoro / Ufficio';
      case PlaceCategory.studio:
        return 'Studio & Università';
      case PlaceCategory.palestra:
        return 'Palestra & Sport';
      case PlaceCategory.svago:
        return 'Svago & Tempo Libero';
      case PlaceCategory.servizi:
        return 'Spesa & Servizi';
      case PlaceCategory.altro:
        return 'Altro';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.casa:
        return Icons.home_rounded;
      case PlaceCategory.secondaCasa:
        return Icons.holiday_village_rounded;
      case PlaceCategory.lavoro:
        return Icons.business_center_rounded;
      case PlaceCategory.secondoLavoro:
        return Icons.work_outline_rounded;
      case PlaceCategory.studio:
        return Icons.school_rounded;
      case PlaceCategory.palestra:
        return Icons.fitness_center_rounded;
      case PlaceCategory.svago:
        return Icons.coffee_rounded;
      case PlaceCategory.servizi:
        return Icons.shopping_bag_rounded;
      case PlaceCategory.altro:
        return Icons.location_on_rounded;
    }
  }

  Color get defaultColor {
    switch (this) {
      case PlaceCategory.casa:
        return const Color(0xFFF59E0B); // Amber
      case PlaceCategory.secondaCasa:
        return const Color(0xFFD97706); // Warm Ochre
      case PlaceCategory.lavoro:
        return const Color(0xFF3B82F6); // Blue
      case PlaceCategory.secondoLavoro:
        return const Color(0xFF0284C7); // Sky Blue
      case PlaceCategory.studio:
        return const Color(0xFF8B5CF6); // Violet
      case PlaceCategory.palestra:
        return const Color(0xFF10B981); // Emerald
      case PlaceCategory.svago:
        return const Color(0xFFEC4899); // Pink
      case PlaceCategory.servizi:
        return const Color(0xFF14B8A6); // Teal
      case PlaceCategory.altro:
        return const Color(0xFF64748B); // Slate
    }
  }

  static PlaceCategory fromString(String? val) {
    if (val == null) return PlaceCategory.altro;
    final clean = val.toLowerCase().replaceAll('_', '');
    return PlaceCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == clean,
      orElse: () => PlaceCategory.altro,
    );
  }
}
