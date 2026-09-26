import 'package:flutter/material.dart';

class PlaceCategory {
  final String id;
  final String name;
  final String displayName;
  final IconData icon;
  final Color defaultColor;
  final bool isCustom;

  const PlaceCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.defaultColor,
    this.isCustom = false,
  });

  static const PlaceCategory casa = PlaceCategory(
    id: 'casa',
    name: 'casa',
    displayName: 'Casa',
    icon: Icons.home_rounded,
    defaultColor: Color(0xFFF59E0B), // Amber
  );

  static const PlaceCategory secondaCasa = PlaceCategory(
    id: 'secondaCasa',
    name: 'secondaCasa',
    displayName: 'Seconda Casa',
    icon: Icons.holiday_village_rounded,
    defaultColor: Color(0xFFD97706), // Warm Ochre
  );

  static const PlaceCategory lavoro = PlaceCategory(
    id: 'lavoro',
    name: 'lavoro',
    displayName: 'Lavoro',
    icon: Icons.business_center_rounded,
    defaultColor: Color(0xFF3B82F6), // Blue
  );

  static const PlaceCategory secondoLavoro = PlaceCategory(
    id: 'secondoLavoro',
    name: 'secondoLavoro',
    displayName: 'Secondo Lavoro / Ufficio',
    icon: Icons.work_outline_rounded,
    defaultColor: Color(0xFF0284C7), // Sky Blue
  );

  static const PlaceCategory studio = PlaceCategory(
    id: 'studio',
    name: 'studio',
    displayName: 'Studio & Università',
    icon: Icons.school_rounded,
    defaultColor: Color(0xFF8B5CF6), // Violet
  );

  static const PlaceCategory palestra = PlaceCategory(
    id: 'palestra',
    name: 'palestra',
    displayName: 'Palestra & Sport',
    icon: Icons.fitness_center_rounded,
    defaultColor: Color(0xFF10B981), // Emerald
  );

  static const PlaceCategory svago = PlaceCategory(
    id: 'svago',
    name: 'svago',
    displayName: 'Svago & Tempo Libero',
    icon: Icons.coffee_rounded,
    defaultColor: Color(0xFFEC4899), // Pink
  );

  static const PlaceCategory servizi = PlaceCategory(
    id: 'servizi',
    name: 'servizi',
    displayName: 'Spesa & Servizi',
    icon: Icons.shopping_bag_rounded,
    defaultColor: Color(0xFF14B8A6), // Teal
  );

  static const PlaceCategory altro = PlaceCategory(
    id: 'altro',
    name: 'altro',
    displayName: 'Altro',
    icon: Icons.location_on_rounded,
    defaultColor: Color(0xFF64748B), // Slate
  );

  static const List<PlaceCategory> defaultCategories = [
    casa,
    secondaCasa,
    lavoro,
    secondoLavoro,
    studio,
    palestra,
    svago,
    servizi,
    altro,
  ];

  static final Map<String, PlaceCategory> _customRegistry = {};

  static void registerCustomCategory(PlaceCategory category) {
    _customRegistry[category.id] = category;
    _customRegistry[category.name.toLowerCase()] = category;
  }

  static void unregisterCustomCategory(String id) {
    final cat = _customRegistry[id];
    if (cat != null) {
      _customRegistry.remove(cat.id);
      _customRegistry.remove(cat.name.toLowerCase());
    }
  }

  static void clearCustomCategories() {
    _customRegistry.clear();
  }

  static List<PlaceCategory> get values {
    final seenIds = <String>{};
    final list = <PlaceCategory>[];

    for (final c in defaultCategories) {
      if (seenIds.add(c.id)) {
        list.add(c);
      }
    }

    for (final c in _customRegistry.values) {
      if (seenIds.add(c.id)) {
        list.add(c);
      }
    }

    return list;
  }

  static PlaceCategory fromString(String? val) {
    if (val == null || val.trim().isEmpty) return PlaceCategory.altro;
    final clean = val.trim().toLowerCase().replaceAll('_', '');

    // 1. Check custom registry first
    for (final c in _customRegistry.values) {
      if (c.id.toLowerCase() == clean ||
          c.name.toLowerCase().replaceAll('_', '') == clean ||
          c.displayName.toLowerCase() == val.trim().toLowerCase()) {
        return c;
      }
    }

    // 2. Check defaults
    for (final c in defaultCategories) {
      if (c.name.toLowerCase().replaceAll('_', '') == clean ||
          c.displayName.toLowerCase() == val.trim().toLowerCase()) {
        return c;
      }
    }

    return PlaceCategory.altro;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'iconCodePoint': icon.codePoint,
      'colorValue': defaultColor.value,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  /// Resolve an icon from its codePoint using compile-time constant icon references
  /// to ensure Flutter release icon tree-shaking succeeds without error.
  static IconData resolveIcon(int? codePoint) {
    if (codePoint == null) return Icons.folder_special_rounded;
    return _iconByCodePoint[codePoint] ?? Icons.folder_special_rounded;
  }

  static final Map<int, IconData> _iconByCodePoint = {
    // Default categories
    Icons.home_rounded.codePoint: Icons.home_rounded,
    Icons.business_center_rounded.codePoint: Icons.business_center_rounded,
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.local_cafe_rounded.codePoint: Icons.local_cafe_rounded,
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.shopping_bag_rounded.codePoint: Icons.shopping_bag_rounded,
    Icons.storefront_rounded.codePoint: Icons.storefront_rounded,
    Icons.park_rounded.codePoint: Icons.park_rounded,
    Icons.school_rounded.codePoint: Icons.school_rounded,
    Icons.medical_services_rounded.codePoint: Icons.medical_services_rounded,
    Icons.family_restroom_rounded.codePoint: Icons.family_restroom_rounded,
    Icons.people_alt_rounded.codePoint: Icons.people_alt_rounded,
    Icons.favorite_rounded.codePoint: Icons.favorite_rounded,
    Icons.directions_bus_rounded.codePoint: Icons.directions_bus_rounded,
    Icons.folder_special_rounded.codePoint: Icons.folder_special_rounded,
    // Picker icons
    Icons.star_rounded.codePoint: Icons.star_rounded,
    Icons.local_hospital_rounded.codePoint: Icons.local_hospital_rounded,
    Icons.local_pharmacy_rounded.codePoint: Icons.local_pharmacy_rounded,
    Icons.shopping_cart_rounded.codePoint: Icons.shopping_cart_rounded,
    Icons.pool_rounded.codePoint: Icons.pool_rounded,
    Icons.sports_soccer_rounded.codePoint: Icons.sports_soccer_rounded,
    Icons.sports_tennis_rounded.codePoint: Icons.sports_tennis_rounded,
    Icons.beach_access_rounded.codePoint: Icons.beach_access_rounded,
    Icons.cabin_rounded.codePoint: Icons.cabin_rounded,
    Icons.menu_book_rounded.codePoint: Icons.menu_book_rounded,
    Icons.handshake_rounded.codePoint: Icons.handshake_rounded,
    Icons.child_care_rounded.codePoint: Icons.child_care_rounded,
    Icons.pets_rounded.codePoint: Icons.pets_rounded,
    Icons.airport_shuttle_rounded.codePoint: Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded.codePoint: Icons.directions_car_rounded,
    Icons.two_wheeler_rounded.codePoint: Icons.two_wheeler_rounded,
    Icons.flight_takeoff_rounded.codePoint: Icons.flight_takeoff_rounded,
    Icons.music_note_rounded.codePoint: Icons.music_note_rounded,
    Icons.movie_rounded.codePoint: Icons.movie_rounded,
    Icons.palette_rounded.codePoint: Icons.palette_rounded,
    Icons.church_rounded.codePoint: Icons.church_rounded,
    Icons.construction_rounded.codePoint: Icons.construction_rounded,
    Icons.apartment_rounded.codePoint: Icons.apartment_rounded,
    Icons.weekend_rounded.codePoint: Icons.weekend_rounded,
    Icons.home_work_rounded.codePoint: Icons.home_work_rounded,
    Icons.work_outline_rounded.codePoint: Icons.work_outline_rounded,
    Icons.science_rounded.codePoint: Icons.science_rounded,
    Icons.place_rounded.codePoint: Icons.place_rounded,
    Icons.location_on_rounded.codePoint: Icons.location_on_rounded,
    Icons.directions_walk_rounded.codePoint: Icons.directions_walk_rounded,
    Icons.directions_bike_rounded.codePoint: Icons.directions_bike_rounded,
    Icons.category_rounded.codePoint: Icons.category_rounded,
  };

  factory PlaceCategory.fromMap(Map<String, dynamic> map) {
    final codePoint = map['iconCodePoint'] as int? ?? Icons.folder_special_rounded.codePoint;
    final colorVal = map['colorValue'] as int? ?? const Color(0xFF6366F1).value;

    return PlaceCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      displayName: map['displayName'] as String,
      icon: resolveIcon(codePoint),
      defaultColor: Color(colorVal),
      isCustom: (map['isCustom'] as int? ?? 1) == 1,
    );
  }

  PlaceCategory copyWith({
    String? id,
    String? name,
    String? displayName,
    IconData? icon,
    Color? defaultColor,
    bool? isCustom,
  }) {
    return PlaceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      defaultColor: defaultColor ?? this.defaultColor,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceCategory &&
          (id == other.id || name.toLowerCase() == other.name.toLowerCase());

  @override
  int get hashCode => name.toLowerCase().hashCode;

  @override
  String toString() => 'PlaceCategory($name, $displayName)';
}
