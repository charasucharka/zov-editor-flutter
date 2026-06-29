import 'package:collection/collection.dart';
import 'package:c_editor/data/grid_override_module_utils.dart';
import 'package:c_editor/data/level_parser.dart';
import 'package:c_editor/data/pvz_models.dart';
import 'package:c_editor/data/rtid_parser.dart';
import 'package:c_editor/l10n/app_localizations.dart';

enum GridPreviewModuleKind {
  common,
  piratePlank,
  railcart,
  mechanismPlank,
  armrack,
  energyGrid,
  bronzeStatue,
  powerTile,
  fogSystem,
  tideSystem,
  smokePollution,
  manholePipeline,
  renaissance,
  roofProperties,
  tunnelDefend,
  gulliverTunnel,
}

class GridPreviewCategoryOption {
  const GridPreviewCategoryOption({
    required this.kind,
    required this.label,
    this.wave,
    this.index,
  });

  final GridPreviewModuleKind kind;
  final String label;
  final int? wave;
  final int? index;

  String get key {
    if (wave != null) return '${kind.name}:w$wave';
    if (index != null) return '${kind.name}:i$index';
    return kind.name;
  }
}

bool levelHasPrePlacedGridPreview(PvzLevelFile levelFile) => true;

bool levelHasCommonGridItems(PvzLevelFile levelFile) {
  return levelFile.objects.any((o) => o.objClass == 'InitialGridItemProperties');
}

List<GridPreviewCategoryOption> collectGridPreviewCategories(
    PvzLevelFile levelFile,
    AppLocalizations l10n,
    ) {
  final categories = <GridPreviewCategoryOption>[];

  categories.add(GridPreviewCategoryOption(
    kind: GridPreviewModuleKind.common,
    label: l10n.previewRegularPlants,
  ));

  void addModule(GridPreviewModuleKind kind, String label) {
    categories.add(GridPreviewCategoryOption(kind: kind, label: label));
  }

  if (levelHasModule(levelFile, 'PiratePlankProperties')) {
    addModule(GridPreviewModuleKind.piratePlank, l10n.moduleTitle_PiratePlankProperties);
  }
  if (levelHasModule(levelFile, 'RailcartProperties')) {
    addModule(GridPreviewModuleKind.railcart, l10n.moduleTitle_RailcartProperties);
  }
  if (levelHasModule(levelFile, 'MechanismPlankProperties')) {
    addModule(GridPreviewModuleKind.mechanismPlank, l10n.moduleTitle_MechanismPlankProperties);
  }
  if (levelHasModule(levelFile, 'BronzeProperties')) {
    addModule(GridPreviewModuleKind.bronzeStatue, l10n.moduleTitle_BronzeProperties);
  }
  if (levelHasModule(levelFile, 'PowerTileProperties')) {
    addModule(GridPreviewModuleKind.powerTile, l10n.moduleTitle_PowerTileProperties);
  }
  if (levelHasModule(levelFile, 'WarMistProperties')) {
    addModule(GridPreviewModuleKind.fogSystem, l10n.moduleTitle_WarMistProperties);
  }
  if (levelHasModule(levelFile, 'TideProperties')) {
    addModule(GridPreviewModuleKind.tideSystem, l10n.moduleTitle_TideProperties);
  }
  if (levelHasModule(levelFile, 'SmokePollutionModuleProperties')) {
    addModule(GridPreviewModuleKind.smokePollution, l10n.moduleTitle_SmokePollutionModuleProperties);
  }
  if (levelHasModule(levelFile, 'ManholePipelineModuleProperties')) {
    final pipeData = readManholePipelineData(levelFile);
    if (pipeData != null) {
      if (pipeData.pipelineList.length <= 1) {
        addModule(GridPreviewModuleKind.manholePipeline,
            l10n.moduleTitle_ManholePipelineModuleProperties);
      } else {
        for (int i = 0; i < pipeData.pipelineList.length; i++) {
          categories.add(GridPreviewCategoryOption(
            kind: GridPreviewModuleKind.manholePipeline,
            label: l10n.pipeN(i + 1),
            index: i,
          ));
        }
      }
    }
  }
  final renaiData = readRenaiModuleData(levelFile);
  if (renaiData != null) {
    addModule(GridPreviewModuleKind.renaissance, l10n.renaiModuleDayStatues);

    if (renaiData.nightEnabled) {
      categories.add(GridPreviewCategoryOption(
        kind: GridPreviewModuleKind.renaissance,
        label: l10n.renaiModuleNightStatues,
        index: 1,
      ));
    }
  }
  if (levelHasModule(levelFile, 'RoofProperties')) {
    addModule(GridPreviewModuleKind.roofProperties, l10n.moduleTitle_RoofProperties);
  }
  if (levelHasModule(levelFile, 'TunnelDefendModuleProperties')) {
    addModule(GridPreviewModuleKind.tunnelDefend, l10n.moduleTitle_TunnelDefendModuleProperties);
  }
  if (levelHasModule(levelFile, 'InitialGridItemGulliverTunnelProperties')) {
    addModule(GridPreviewModuleKind.gulliverTunnel, l10n.moduleTitle_InitialGridItemGulliverTunnelProperties);
  }

  final armrackData = readArmrackModuleData(levelFile);
  if (armrackData != null) {
    final waves = armrackData.overrides.map((o) => o.wave).toSet().toList()..sort();
    for (final wave in waves) {
      categories.add(GridPreviewCategoryOption(
        kind: GridPreviewModuleKind.armrack,
        label: _waveCategoryLabel(l10n, l10n.moduleTitle_ArmrackProperties, wave, waves.length),
        wave: wave,
      ));
    }
  }

  final energyData = readEnergyGridModuleData(levelFile);
  if (energyData != null) {
    final waves = energyData.overrides.map((o) => o.wave).toSet().toList()..sort();
    for (final wave in waves) {
      categories.add(GridPreviewCategoryOption(
        kind: GridPreviewModuleKind.energyGrid,
        label: _waveCategoryLabel(l10n, l10n.moduleTitle_EnergyGridProperties, wave, waves.length),
        wave: wave,
      ));
    }
  }

  return categories;
}

String _waveCategoryLabel(AppLocalizations l10n, String moduleTitle, int wave, int waveCount) {
  if (waveCount <= 1) return moduleTitle;
  return '$moduleTitle · ${l10n.waveLabel} $wave';
}

PvzObject? findModuleObject(PvzLevelFile levelFile, String objClass) {
  final direct = levelFile.objects.firstWhereOrNull((o) => o.objClass == objClass);
  if (direct != null) return direct;

  final parsed = LevelParser.parseLevel(levelFile);
  final modules = parsed.levelDef?.modules ?? [];

  final moduleAliases = modules.map((m) => RtidParser.parse(m)?.alias).whereType<String>().toSet();

  for (final obj in levelFile.objects) {
    if (obj.objClass == objClass) {
      if (obj.aliases != null && obj.aliases!.any((a) => moduleAliases.contains(a))) {
        return obj;
      }
    }
  }
  return null;
}

SmokePollutionModulePropertiesData? readSmokePollutionData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'SmokePollutionModuleProperties');
  return obj != null ? SmokePollutionModulePropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

ManholePipelineModuleData? readManholePipelineData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'ManholePipelineModuleProperties');
  return obj != null ? ManholePipelineModuleData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

RenaiModulePropertiesData? readRenaiModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'RenaiModuleProperties');
  return obj != null ? RenaiModulePropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

RoofPropertiesData? readRoofPropertiesData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'RoofProperties');
  return obj != null ? RoofPropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

TunnelDefendModuleData? readTunnelDefendData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'TunnelDefendModuleProperties');
  return obj != null ? TunnelDefendModuleData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

InitialGridItemGulliverTunnelPropertiesData? readGulliverTunnelData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'InitialGridItemGulliverTunnelProperties');
  return obj != null ? InitialGridItemGulliverTunnelPropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

PiratePlankPropertiesData? readPiratePlankModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'PiratePlankProperties');
  return obj != null ? PiratePlankPropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

RailcartPropertiesData? readRailcartModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'RailcartProperties');
  return obj != null ? RailcartPropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

BronzePropertiesData? readBronzeModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'BronzeProperties');
  return obj != null ? BronzePropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

PowerTilePropertiesData? readPowerTileModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'PowerTileProperties');
  return obj != null ? PowerTilePropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

WarMistPropertiesData? readWarMistModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'WarMistProperties');
  return obj != null ? WarMistPropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

TidePropertiesData? readTideModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'TideProperties');
  return obj != null ? TidePropertiesData.fromJson(Map<String, dynamic>.from(obj.objData as Map)) : null;
}

Map<String, dynamic>? readMechanismPlankModuleData(PvzLevelFile levelFile) {
  final obj = findModuleObject(levelFile, 'MechanismPlankProperties');
  return obj != null ? Map<String, dynamic>.from(obj.objData as Map) : null;
}

List<List<bool>> buildRailcartRailsGrid(RailcartPropertiesData data, int rows, int cols) {
  final grid = List.generate(cols, (_) => List.filled(rows, false));
  for (final rail in data.rails) {
    for (var r = rail.rowStart; r <= rail.rowEnd; r++) {
      if (rail.column >= 0 && rail.column < cols && r >= 0 && r < rows) grid[rail.column][r] = true;
    }
  }
  return grid;
}

Set<String> buildRailcartCartSet(RailcartPropertiesData data) {
  return data.railcarts.map((c) => '${c.column},${c.row}').toSet();
}

class MechanismPlankPreviewState {
  const MechanismPlankPreviewState({required this.mX, required this.mY, required this.mWidth, required this.mHeight, required this.cartLocalRows});
  final int mX, mY, mWidth, mHeight; final Set<int> cartLocalRows;
  bool isInsideRect(int col, int row) => col >= mX && col < mX + mWidth && row >= mY && row < mY + mHeight;
  bool hasRailAt(int col, int row) {
    if (!isInsideRect(col, row)) return false;
    return cartLocalRows.any((cartRow) => (row - mY - cartRow).abs() <= 1);
  }
  bool hasCartAt(int col, int row) => isInsideRect(col, row) && cartLocalRows.contains(row - mY);
  String cartAssetKind(int col) => mWidth <= 1 ? 'middle' : (col <= mX ? 'left' : (col >= mX + mWidth - 1 ? 'right' : 'middle'));
}

MechanismPlankPreviewState? buildMechanismPlankPreviewState(Map<String, dynamic>? data) {
  if (data == null) return null;
  final rect = Map<String, dynamic>.from(data['MechanismGearsRect'] as Map? ?? {});
  final plankRows = ((data['MechanismPlankRows'] as List?) ?? ['0', '4']).map((e) => int.tryParse(e.toString())).whereType<int>().toSet();
  return MechanismPlankPreviewState(mX: (rect['mX'] as num?)?.toInt() ?? 0, mY: (rect['mY'] as num?)?.toInt() ?? 0, mWidth: (rect['mWidth'] as num?)?.toInt() ?? 4, mHeight: (rect['mHeight'] as num?)?.toInt() ?? 5, cartLocalRows: plankRows);
}