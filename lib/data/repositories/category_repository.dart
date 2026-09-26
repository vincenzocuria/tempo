import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/place_category.dart';
import '../services/database_service.dart';
import 'place_repository.dart';

class CategoryRepository extends ChangeNotifier {
  final DatabaseService _dbService;

  CategoryRepository({DatabaseService? databaseService})
      : _dbService = databaseService ?? DatabaseService.instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  List<PlaceCategory> get categories => PlaceCategory.values;

  List<PlaceCategory> get customCategories =>
      categories.where((c) => c.isCustom).toList();

  List<PlaceCategory> get defaultCategories => PlaceCategory.defaultCategories;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final customCats = await _dbService.getAllCustomCategories();
      for (final cat in customCats) {
        PlaceCategory.registerCustomCategory(cat);
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing CategoryRepository: $e');
    }
  }

  Future<PlaceCategory> addCategory({
    required String displayName,
    required IconData icon,
    required Color color,
  }) async {
    final cleanName = displayName.trim();
    final id = 'cat_${const Uuid().v4().substring(0, 8)}';

    final newCat = PlaceCategory(
      id: id,
      name: id,
      displayName: cleanName,
      icon: icon,
      defaultColor: color,
      isCustom: true,
    );

    await _dbService.insertCustomCategory(newCat);
    PlaceCategory.registerCustomCategory(newCat);
    notifyListeners();
    return newCat;
  }

  Future<void> updateCategory(PlaceCategory category) async {
    await _dbService.updateCustomCategory(category);
    PlaceCategory.registerCustomCategory(category);
    notifyListeners();
  }

  Future<void> deleteCategory(
    String categoryId, {
    PlaceRepository? placeRepository,
  }) async {
    await _dbService.deleteCustomCategory(categoryId);
    PlaceCategory.unregisterCustomCategory(categoryId);

    // If places are associated with this category, reassign them safely to PlaceCategory.altro
    if (placeRepository != null) {
      try {
        final allPlaces = await placeRepository.getAllPlaces();
        for (final p in allPlaces) {
          if (p.category.id == categoryId || p.category.name == categoryId) {
            final updated = p.copyWith(category: PlaceCategory.altro);
            await placeRepository.updatePlace(updated);
          }
        }
      } catch (e) {
        debugPrint('Error reassigning places on category delete: $e');
      }
    }

    notifyListeners();
  }

  PlaceCategory findByIdOrName(String? val) {
    return PlaceCategory.fromString(val);
  }
}
