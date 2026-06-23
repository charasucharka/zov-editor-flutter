import 'package:flutter/widgets.dart';
import 'package:c_editor/data/repository/stage_catalog_repository.dart';

/// Stage data for level editor selection UI.
enum StageType { all, main, extra, seasons, special }

class StageItem {
  const StageItem({required this.alias, this.iconName, required this.type});

  final String alias;
  final String? iconName;
  final StageType type;
}

class StageRepository {
  StageRepository._();

  static final List<StageItem> _database = [];
  static bool _isLoaded = false;

  static Future<void> init() async {
    if (_isLoaded) return;
    try {
      await StageCatalogRepository.init();
      _database
        ..clear()
        ..addAll(_buildItemsFromCatalog());
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading stages: $e');
    }
  }

  static List<StageItem> _buildItemsFromCatalog() {
    final out = <StageItem>[];
    final seen = <String>{};

    // Keep the same order as Stages_tags.json by reusing the alias-ordered
    // base stage options from StageCatalogRepository.
    for (final option in StageCatalogRepository.stageBaseOptions()) {
      if (!seen.add(option.alias)) continue;
      out.add(
        StageItem(
          alias: option.alias,
          iconName: option.iconName,
          type: _parseType(option.type),
        ),
      );
    }

    return out;
  }

  static List<StageItem> get allItems => List.unmodifiable(_database);

  static List<StageItem> getByType(StageType type) {
    if (type == StageType.all) return allItems;
    return _database.where((s) => s.type == type).toList();
  }

  /// Localization key for stage name. Use ResourceNames.lookup(context, getName(alias)).
  static String getName(String alias) => 'stage_$alias';

  static StageType _parseType(Object? raw) {
    if (raw is StageType) return raw;
    final value = raw?.toString().split('.').last;
    return StageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StageType.main,
    );
  }
}
