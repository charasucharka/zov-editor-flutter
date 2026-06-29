import 'package:flutter/material.dart';
import 'package:c_editor/data/pvz_models.dart';
import 'package:c_editor/data/level_parser.dart';
import 'package:c_editor/data/rtid_parser.dart';
import 'package:c_editor/data/custom_stage_level_utils.dart';
import 'package:c_editor/data/repository/plant_repository.dart';
import 'package:c_editor/data/repository/zombie_repository.dart';
import 'package:c_editor/data/repository/grid_item_repository.dart';
import 'package:c_editor/data/repository/stage_repository.dart';
import 'package:c_editor/l10n/app_localizations.dart';
import 'package:c_editor/l10n/resource_names.dart';
import 'package:c_editor/data/armrack_type_catalog.dart';
import 'package:c_editor/data/repository/tool_repository.dart';
import 'package:c_editor/data/grid_override_module_utils.dart';
import 'package:c_editor/screens/common/level_preview_grid_helpers.dart';
import 'package:c_editor/widgets/asset_image.dart' show AssetImageWidget, imageAltCandidates;
import 'package:c_editor/widgets/editor_components.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';

class LevelPreviewDialog extends StatefulWidget {
  final PvzLevelFile levelFile;
  final ParsedLevelData parsed;
  final String fileName;
  final VoidCallback onBack;

  const LevelPreviewDialog({
    super.key,
    required this.levelFile,
    required this.parsed,
    required this.fileName,
    required this.onBack,
  });

  @override
  State<LevelPreviewDialog> createState() => _LevelPreviewDialogState();
}

class _LevelPreviewDialogState extends State<LevelPreviewDialog> {
  int _prePlacedTabIndex = 0;
  int _plantTypeIndex = 0;
  String? _gridItemCategoryKey;
  bool _isLoadingRepos = true;

  bool _blackListExpanded = false;
  bool _whiteListExpanded = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([
      PlantRepository().init(),
      ZombieRepository().init(),
      GridItemRepository.init(),
      StageRepository.init(),
    ]);
    if (mounted) {
      setState(() => _isLoadingRepos = false);
    }
  }

  String _getModuleLabel(GridPreviewModuleKind kind, AppLocalizations l10n) {
    switch (kind) {
      case GridPreviewModuleKind.common: return l10n.previewRegularPlants;
      case GridPreviewModuleKind.piratePlank: return l10n.moduleTitle_PiratePlankProperties;
      case GridPreviewModuleKind.railcart: return l10n.moduleTitle_RailcartProperties;
      case GridPreviewModuleKind.mechanismPlank: return l10n.moduleTitle_MechanismPlankProperties;
      case GridPreviewModuleKind.armrack: return l10n.moduleTitle_ArmrackProperties;
      case GridPreviewModuleKind.energyGrid: return l10n.moduleTitle_EnergyGridProperties;
      case GridPreviewModuleKind.bronzeStatue: return l10n.moduleTitle_BronzeProperties;
      case GridPreviewModuleKind.powerTile: return l10n.moduleTitle_PowerTileProperties;
      case GridPreviewModuleKind.fogSystem: return l10n.moduleTitle_WarMistProperties;
      case GridPreviewModuleKind.tideSystem: return l10n.moduleTitle_TideProperties;
      case GridPreviewModuleKind.smokePollution: return l10n.moduleTitle_SmokePollutionModuleProperties;
      case GridPreviewModuleKind.manholePipeline: return l10n.moduleTitle_ManholePipelineModuleProperties;
      case GridPreviewModuleKind.renaissance: return l10n.moduleTitle_RenaiModuleProperties;
      case GridPreviewModuleKind.roofProperties: return l10n.moduleTitle_RoofProperties;
      case GridPreviewModuleKind.tunnelDefend: return l10n.moduleTitle_TunnelDefendModuleProperties;
      case GridPreviewModuleKind.gulliverTunnel: return l10n.moduleTitle_InitialGridItemGulliverTunnelProperties;
    }
  }

  String _cleanId(String id) {
    if (id.contains('(') && id.contains('@')) {
      return LevelParser.extractAlias(id);
    }
    return id;
  }

  int _parseCoord(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return double.tryParse(val.toString())?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final levelDef = widget.parsed.levelDef;

    if (_isLoadingRepos) {
      return const Scaffold(
        backgroundColor: Color(0xFF141414),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (levelDef == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(child: Text('Error: No level definition found.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: Text(l10n.levelPreview),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(context, levelDef, theme, l10n),
            const SizedBox(height: 12),
            _buildSeedBankCard(context, theme, l10n),
            const SizedBox(height: 12),
            _buildConveyorCard(context, theme, l10n),
            const SizedBox(height: 12),
            _buildPrePlacedCard(context, theme, l10n),
            const SizedBox(height: 12),
            _buildEncounterCard(context, theme, l10n),
            const SizedBox(height: 12),
            _buildModulesCard(context, theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color ?? theme.colorScheme.primary.withValues(alpha: 0.9),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, LevelDefinitionData def, ThemeData theme, AppLocalizations l10n) {
    final stageInfo = RtidParser.parse(def.stageModule);
    final stageAlias = stageInfo?.alias ?? 'Unknown';
    final stageSource = stageInfo?.source ?? 'Unknown';

    String worldName;
    String customSuffix = "";
    String? stageIconFile;

    if (stageSource == CustomStageLevelUtils.currentLevel) {
      customSuffix = " (${l10n.customLabel.toLowerCase()})";
      final stageObj = CustomStageLevelUtils.findStageObject(widget.levelFile, stageAlias);
      if (stageObj != null && stageObj.objData is Map) {
        final objDataMap = Map<String, dynamic>.from(stageObj.objData as Map);
        final nameKey = CustomStageLevelUtils.displayStageBaseNameKey(
          objclass: stageObj.objClass,
          objdata: objDataMap,
        );
        worldName = ResourceNames.lookup(context, nameKey);
        stageIconFile = CustomStageLevelUtils.displayIconFileName(
          objclass: stageObj.objClass,
          objdata: objDataMap,
        );
      } else {
        worldName = l10n.customLabel;
      }
    } else {
      final stageNameKey = StageRepository.getName(stageAlias);
      worldName = ResourceNames.lookup(context, stageNameKey);
      final stageItem = StageRepository.allItems.firstWhereOrNull((s) => s.alias == stageAlias);
      stageIconFile = stageItem?.iconName;
    }

    final stageIconPath = stageIconFile != null ? 'assets/images/round_icons/$stageIconFile' : null;

    int startingSun = def.startingSun ?? 0;
    int pfCount = 0;

    bool skySunEnabled = widget.levelFile.objects.any((o) =>
    o.objClass == 'SunDropperProperties' ||
        o.objClass == 'SunDroppingModuleProperties' ||
        o.objClass == 'SunDropperModuleProperties'
    ) || def.modules.any((m) => m.contains('SunDropper'));

    bool hasSunBombModule = widget.levelFile.objects.any((o) =>
    o.objClass == 'SunBombChallengeProperties'
    ) || def.modules.any((m) => m.contains('SunBomb'));

    // Бомбы активны только если есть и дождь, и модуль бомб
    bool sunBombsActive = skySunEnabled && hasSunBombModule;

    for (var o in widget.levelFile.objects) {
      final data = o.objData;
      if (data is Map) {
        if (o.objClass == 'LevelMutatorStartingPlantfoodProps') {
          pfCount = data['StartingPlantfoodOverride'] ?? data['StartingPlantfood'] ?? 0;
        } else if (o.objClass == 'LastStandMinigameProperties' || o.objClass == 'ZombossLastStandMinigameProperties') {
          if (data['StartingSun'] != null) startingSun = data['StartingSun'];
          if (data['StartingPlantfood'] != null) pfCount = data['StartingPlantfood'];
        }
      }
    }

    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.levelBasicInfo, theme),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.name}: ${def.name.isEmpty ? widget.fileName : def.name}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (def.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.description}: ${def.description}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.stageModule}: $worldName$customSuffix',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (stageIconPath != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      child: AssetImageWidget(
                        assetPath: stageIconPath,
                        width: 84,
                        height: 84,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ResourceChip(icon: Icons.wb_sunny, label: '$startingSun', color: Colors.orange),
                const SizedBox(width: 10),
                _ResourceChip(icon: Icons.eco, label: '$pfCount', color: Colors.greenAccent),
                const SizedBox(width: 10),
                _ResourceChip(
                  icon: sunBombsActive
                      ? Icons.wb_iridescent
                      : (skySunEnabled ? Icons.wb_sunny_outlined : Icons.sunny_snowing),
                  label: sunBombsActive ? '!' : (skySunEnabled ? '✓' : '✕'),
                  color: sunBombsActive
                      ? Colors.deepPurpleAccent
                      : (skySunEnabled ? Colors.lightBlueAccent : Colors.redAccent),
                  tooltip: sunBombsActive
                      ? 'Падают солнечные бомбы'
                      : (skySunEnabled ? 'Солнца падают с неба' : 'Солнца не падают с неба'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedBankCard(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    PvzObject? sbObj = widget.levelFile.objects.firstWhereOrNull((o) => o.objClass == 'SeedBankProperties');
    if (sbObj == null) return const SizedBox.shrink();

    final data = sbObj.objData as Map;
    final List<String> presetPlants = [];
    final List<String> blackList = [];
    final List<String> whiteList = [];

    final method = data['SelectionMethod'] ?? 'chooser';
    final plantLevel = data['GlobalLevel'] ?? data['PlantLevel'] ?? 0;
    final isZombieMode = data['ZombieMode'] == true;
    final isReversedFaction = data['SeedPacketType'] == 'UIIZombieSeedPacket';

    void addList(dynamic raw, List<String> out) {
      if (raw is List) {
        for (var e in raw) {
          if (e is String) {
            out.add(_cleanId(e));
          } else if (e is Map) {
            final id = e['PlantType'] ?? e['PlantTypeName'] ?? e['TypeName'] ?? e['Type'];
            if (id is String) {
              out.add(_cleanId(id));
            }
          }
        }
      }
    }

    addList(data['PresetPlantList'], presetPlants);
    addList(data['PlantBlackList'] ?? data['BlackList'], blackList);
    addList(data['PlantWhiteList'] ?? data['WhiteList'], whiteList);

    final bool isDataEmpty = presetPlants.isEmpty && blackList.isEmpty && whiteList.isEmpty;
    final String levelText = plantLevel == 0 ? "как в коллекции (у игрока)" : "$plantLevel";

    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.previewSeedBank, theme),

            if (isDataEmpty) ...[
              if (method == 'preset')
                const Text("Выбор игрока невозможен", style: TextStyle(fontSize: 16, color: Colors.white70))
              else if (!isZombieMode)
                const Text("На выбор игрока", style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],

            if (presetPlants.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPlantListSection("Заранее выданные", presetPlants, true),
            ],
            if (whiteList.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPlantListSection("Белый список", whiteList, _whiteListExpanded,
                  onExpand: () => setState(() => _whiteListExpanded = true)),
            ],
            if (blackList.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPlantListSection("Чёрный список", blackList, _blackListExpanded,
                  onExpand: () => setState(() => _blackListExpanded = true)),
            ],

            const SizedBox(height: 20),
            if (isZombieMode)
              Row(
                children: [
                  const Icon(Icons.swap_horiz, size: 18, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text("${l10n.reverseZombieFactionTitle}: ", style: const TextStyle(fontSize: 15, color: Colors.blueAccent)),
                  Icon(isReversedFaction ? Icons.check : Icons.close, size: 18, color: isReversedFaction ? Colors.greenAccent : Colors.redAccent),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 18, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text("Уровень растений: $levelText", style: const TextStyle(fontSize: 15, color: Colors.blueAccent)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConveyorCard(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    PvzObject? convObj = widget.levelFile.objects.firstWhereOrNull((o) => o.objClass == 'ConveyorSeedBankProperties');
    if (convObj == null) return const SizedBox.shrink();

    final data = convObj.objData as Map;
    final List<String> plants = [];
    final List<({String id, int wave, bool isAdd})> changes = [];

    void addList(dynamic raw, List<String> out) {
      if (raw is List) {
        for (var e in raw) {
          if (e is String) {
            out.add(_cleanId(e));
          } else if (e is Map) {
            final id = e['PlantType'] ?? e['PlantTypeName'] ?? e['TypeName'] ?? e['Type'];
            if (id is String) {
              out.add(_cleanId(id));
            }
          }
        }
      }
    }

    addList(data['Plants'] ?? data['InitialPlantList'], plants);

    final wm = widget.parsed.waveManager;
    if (wm is WaveManagerData) {
      for (int i = 0; i < wm.waves.length; i++) {
        final waveNum = i + 1;
        for (var rtid in wm.waves[i]) {
          final alias = LevelParser.extractAlias(rtid);
          final obj = widget.parsed.objectMap[alias];
          if (obj != null && obj.objClass == 'ModifyConveyorWaveActionProps') {
            final d = obj.objData;
            if (d is Map) {
              final adds = d['Add'] as List?;
              if (adds != null) {
                for (var e in adds) {
                  if (e is Map) {
                    final t = e['Type'] ?? e['ToolType'];
                    if (t is String) {
                      changes.add((id: _cleanId(t), wave: waveNum, isAdd: true));
                    }
                  }
                }
              }
              final removes = d['Remove'] as List?;
              if (removes != null) {
                for (var e in removes) {
                  if (e is Map) {
                    final t = e['Type'] ?? e['ToolType'];
                    if (t is String) {
                      changes.add((id: _cleanId(t), wave: waveNum, isAdd: false));
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Конвейер", theme),

            if (plants.isNotEmpty)
              _buildPlantListSection("Семена на конвейере", plants, true),

            if (changes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text("Изменения в конвейере", style: TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.bold)),
                  _legendItem(Colors.green, "добавится"),
                  _legendItem(Colors.red, "удалится"),
                  const Text("• Цифра — номер волны", style: TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: changes.map((c) => _ConveyorBadgeIcon(id: c.id, wave: c.wave, isAdd: c.isAdd)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.8), shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ],
    );
  }

  Widget _buildPlantListSection(String title, List<String> items, bool expanded, {VoidCallback? onExpand}) {
    final bool canExpand = items.length > 8 && !expanded;
    final displayItems = canExpand ? items.take(3).toList() : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...displayItems.where((id) => id.isNotEmpty).map((id) => _UniversalIcon(id: id, size: 40)),
            if (canExpand)
              InkWell(
                onTap: onExpand,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text("Развернуть", style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrePlacedCard(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final (rows, cols) = LevelParser.getGridDimensions(widget.parsed.levelDef, widget.levelFile);
    if (!levelHasPrePlacedGridPreview(widget.levelFile)) return const SizedBox.shrink();

    final gridCategories = collectGridPreviewCategories(widget.levelFile, l10n);
    final activeGridKey = _resolveGridItemCategoryKey(gridCategories);
    final activeTabIndex = _prePlacedTabIndex;

    Color tabColor = const Color(0xFF4A5C61);
    if (activeTabIndex == 0) tabColor = const Color(0xFF2E7D32);
    else if (activeTabIndex == 1) tabColor = const Color(0xFF8F76BB);
    else if (activeTabIndex == 2) tabColor = const Color(0xFFD5925E);

    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(l10n.previewPrePlaced, theme, color: tabColor),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l10n.previewTabPlants), icon: const Icon(Icons.local_florist, size: 14)),
                    ButtonSegment(value: 1, label: Text(l10n.previewTabZombies), icon: const Icon(Icons.emoji_nature, size: 14)),
                    ButtonSegment(value: 2, label: Text(l10n.previewTabGridItems), icon: const Icon(Icons.grid_on, size: 14)),
                  ],
                  selected: {activeTabIndex},
                  onSelectionChanged: (set) => setState(() => _prePlacedTabIndex = set.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            if (activeTabIndex == 2)
              Builder(builder: (context) {
                final kinds = gridCategories.map((c) => c.kind).toSet().toList();
                final showSidebar = kinds.length > 1;

                if (!showSidebar) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSubCategoryHeader(gridCategories, activeGridKey, l10n, theme),
                      const SizedBox(height: 12),
                      _buildLawnGrid(rows, cols, tabColor, gridCategories, activeGridKey, activeTabIndex),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 380,
                      child: _buildModuleSidebar(gridCategories, activeGridKey, l10n, theme),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubCategoryHeader(gridCategories, activeGridKey, l10n, theme),
                          const SizedBox(height: 12),
                          _buildLawnGrid(rows, cols, tabColor, gridCategories, activeGridKey, activeTabIndex),
                        ],
                      ),
                    ),
                  ],
                );
              })
            else ...[
              if (activeTabIndex == 0 && widget.levelFile.objects.any((o) => o.objClass == 'FrozenPlantPlacement' || o.objClass == 'InitialPlantProperties'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(l10n.previewRegularPlants)),
                      ButtonSegment(value: 1, label: Text(l10n.previewFrozenPlants)),
                    ],
                    selected: {_plantTypeIndex},
                    onSelectionChanged: (set) => setState(() => _plantTypeIndex = set.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
              _buildLawnGrid(rows, cols, tabColor, gridCategories, activeGridKey, activeTabIndex),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModuleSidebar(List<GridPreviewCategoryOption> categories, String activeKey, AppLocalizations l10n, ThemeData theme) {
    final kinds = categories.map((c) => c.kind).toSet().toList();
    final selectedOption = _selectedGridCategory(categories, activeKey);
    final selectedKind = selectedOption?.kind ?? kinds.first;

    final isMobile = Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: !isMobile), // Скрываем ползунок на мобилках
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: kinds.length,
          itemBuilder: (context, index) {
            final kind = kinds[index];
            final isSelected = kind == selectedKind;
            return InkWell(
              onTap: () {
                final firstOfKind = categories.firstWhere((c) => c.kind == kind);
                setState(() => _gridItemCategoryKey = firstOfKind.key);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
                  border: isSelected ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)) : null,
                ),
                child: Text(
                  _getModuleLabel(kind, l10n),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? theme.colorScheme.primary : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubCategoryHeader(List<GridPreviewCategoryOption> categories, String activeKey, AppLocalizations l10n, ThemeData theme) {
    final selectedOption = _selectedGridCategory(categories, activeKey);
    if (selectedOption == null) return const SizedBox.shrink();

    final optionsForKind = categories.where((c) => c.kind == selectedOption.kind).toList();
    if (optionsForKind.length <= 1) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: optionsForKind.map((option) {
          String label = option.wave != null ? '${l10n.waveLabel} ${option.wave}' : option.label;
          return ButtonSegment<String>(value: option.key, label: Text(label));
        }).toList(),
        selected: {activeKey},
        onSelectionChanged: (set) => setState(() => _gridItemCategoryKey = set.first),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      ),
    );
  }

  String _resolveGridItemCategoryKey(List<GridPreviewCategoryOption> categories) {
    if (categories.isEmpty) return '';
    if (_gridItemCategoryKey != null &&
        categories.any((c) => c.key == _gridItemCategoryKey)) {
      return _gridItemCategoryKey!;
    }
    return categories.first.key;
  }

  GridPreviewCategoryOption? _selectedGridCategory(
      List<GridPreviewCategoryOption> categories,
      String key,
      ) {
    return categories.firstWhereOrNull((c) => c.key == key);
  }

  Widget _buildBronzeStatueGrid(int rows, int cols, Color borderColor) {
    final result = <String, String>{};
    final data = readBronzeModuleData(widget.levelFile);
    if (data != null) {
      for (var batch in data.data) {
        for (var item in batch.itemList) {
          String zombieId = switch (item.kind) {
            BronzeStatueKind.strength => 'kongfu_strong_bronze',
            BronzeStatueKind.mage => 'kongfu_magic_bronze',
            BronzeStatueKind.agile => 'kongfu_agile_bronze',
          };
          result['${item.mX},${item.mY}'] = zombieId;
        }
      }
    }
    return _buildIconLawnGrid(rows, cols, borderColor, result, 1);
  }



  Widget _buildPowerTileGrid(int rows, int cols, Color borderColor) {
    final result = <String, String>{};
    final data = readPowerTileModuleData(widget.levelFile);
    if (data != null) {
      for (var tile in data.linkedTiles) {
        String toolId = 'tool_powertile_${tile.group}';
        result['${tile.location.mx},${tile.location.my}'] = toolId;
      }
    }
    return _buildIconLawnGrid(rows, cols, borderColor, result, 2);
  }

  Widget _buildWarMistGrid(int rows, int cols, Color borderColor) {
    final obj = widget.levelFile.objects.firstWhereOrNull((o) => o.objClass == 'WarMistProperties');
    final mistCol = (obj?.objData as Map?)?['m_iInitMistPosX'] ?? 5;
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) => col >= mistCol ? Container(color: Colors.grey.withValues(alpha: 0.4)) : null,
    );
  }

  Widget _buildTideGrid(int rows, int cols, Color borderColor) {
    final obj = widget.levelFile.objects.firstWhereOrNull((o) => o.objClass == 'TideProperties');
    final tideCol = (obj?.objData as Map?)?['StartingWaveLocation'] ?? 5;
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) => col >= tideCol ? Container(color: Colors.blue.withValues(alpha: 0.3)) : null,
    );
  }

  Widget _buildSmokeGrid(int rows, int cols, Color borderColor) {
    final smokeData = readSmokePollutionData(widget.levelFile);

    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        if (smokeData == null) return null;

        final isSmoke = smokeData.smokeManholeList.any((m) => m.gridColumn == col && m.gridRow == row);
        if (!isSmoke) return null;

        return _getIconForId(smokeData.gridItem, 2, isGrid: true);
      },
    );
  }

  Widget _buildManholeGrid(int rows, int cols, Color borderColor, GridPreviewCategoryOption category) {
    final pipeData = readManholePipelineData(widget.levelFile);
    final l10n = AppLocalizations.of(context)!;
    final selectedIndex = category.index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompositeLawnGrid(
          rows: rows, cols: cols, borderColor: borderColor,
          cellBuilder: (col, row) {
            final markers = <({bool isStart, int index})>[];
            if (pipeData != null) {
              for (int i = 0; i < pipeData.pipelineList.length; i++) {
                final p = pipeData.pipelineList[i];
                if (p.startX == col && p.startY == row) markers.add((isStart: true, index: i));
                if (p.endX == col && p.endY == row) markers.add((isStart: false, index: i));
              }
            }

            if (markers.isEmpty) return null;

            final isTarget = selectedIndex != null && pipeData != null && selectedIndex < pipeData.pipelineList.length &&
                ((pipeData.pipelineList[selectedIndex].startX == col && pipeData.pipelineList[selectedIndex].startY == row) ||
                    (pipeData.pipelineList[selectedIndex].endX == col && pipeData.pipelineList[selectedIndex].endY == row));

            return Container(
              color: isTarget ? Colors.green.withValues(alpha: 0.3) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final m in markers)
                    Opacity(
                      opacity: (selectedIndex == null || selectedIndex == m.index) ? 1.0 : 0.4,
                      child: AssetImageWidget(
                        assetPath: m.isStart ? 'assets/images/griditems/steam_down.webp' : 'assets/images/griditems/steam_up.webp',
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (selectedIndex != null && pipeData != null && selectedIndex < pipeData.pipelineList.length)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.manholePipelineStartEndFormat(
                pipeData.pipelineList[selectedIndex].startX,
                pipeData.pipelineList[selectedIndex].startY,
                pipeData.pipelineList[selectedIndex].endX,
                pipeData.pipelineList[selectedIndex].endY,
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildRenaiGrid(int rows, int cols, Color borderColor, GridPreviewCategoryOption category) {
    final result = <String, String>{};
    final data = readRenaiModuleData(widget.levelFile);
    if (data != null) {
      final statues = category.index == 1 ? data.statueNightInfos : data.statueInfos;
      for (var s in statues) {
        result['${s.gridX},${s.gridY}'] = s.typeName;
      }
    }
    return _buildIconLawnGrid(rows, cols, borderColor, result, 2);
  }

  Widget _buildTunnelDefendGrid(int rows, int cols, Color borderColor) {
    final data = readTunnelDefendData(widget.levelFile);
    return _buildCompositeLawnGrid(
      rows: rows,
      cols: cols,
      borderColor: borderColor,
      aspectRatio: (cols * 128.0) / (rows * 152.0),
      cellBuilder: (col, row) {
        final road = data?.roads.firstWhereOrNull((r) => r.gridX == col && r.gridY == row);
        if (road == null) return null;
        final path = 'assets/images/tunnels/${road.img}.webp';
        return AssetImageWidget(
          assetPath: path,
          altCandidates: imageAltCandidates(path),
          fit: BoxFit.fill,
        );
      },
    );
  }

  Widget _buildGulliverGrid(int rows, int cols, Color borderColor) {
    final data = readGulliverTunnelData(widget.levelFile);
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        final t = data?.tunnelPlacements.firstWhereOrNull((p) => p.gridX == col && p.gridY == row);
        if (t == null) return null;
        final path = 'assets/images/tunnels/${t.orientation}.webp';
        return AssetImageWidget(assetPath: path, altCandidates: imageAltCandidates(path), fit: BoxFit.contain);
      },
    );
  }

  Widget _buildRoofGrid(int rows, int cols, Color borderColor) {
    final data = readRoofPropertiesData(widget.levelFile);
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        if (data != null && col >= data.flowerPotStartColumn && col <= data.flowerPotEndColumn) {
          return const _GridItemIcon(id: 'flowerpot', isGrid: true);
        }
        return null;
      },
    );
  }

  Widget _buildObjectCategorySelection(
      List<GridPreviewCategoryOption> categories,
      String activeGridKey,
      AppLocalizations l10n,
      ThemeData theme,
      ) {
    final selectedOption = _selectedGridCategory(categories, activeGridKey);
    final selectedKind = selectedOption?.kind ?? categories.first.kind;
    final scrollController = ScrollController();

    final kinds = categories.map((c) => c.kind).toSet().toList();

    String kindLabel(GridPreviewModuleKind kind) {
      switch (kind) {
        case GridPreviewModuleKind.common: return l10n.previewRegularPlants;
        case GridPreviewModuleKind.piratePlank: return l10n.moduleTitle_PiratePlankProperties;
        case GridPreviewModuleKind.railcart: return l10n.moduleTitle_RailcartProperties;
        case GridPreviewModuleKind.mechanismPlank: return l10n.moduleTitle_MechanismPlankProperties;
        case GridPreviewModuleKind.armrack: return l10n.moduleTitle_ArmrackProperties;
        case GridPreviewModuleKind.energyGrid: return l10n.moduleTitle_EnergyGridProperties;
        case GridPreviewModuleKind.bronzeStatue: return l10n.moduleTitle_BronzeProperties;
        case GridPreviewModuleKind.powerTile: return l10n.moduleTitle_PowerTileProperties;
        case GridPreviewModuleKind.fogSystem: return l10n.moduleTitle_WarMistProperties;
        case GridPreviewModuleKind.tideSystem: return l10n.moduleTitle_TideProperties;
        case GridPreviewModuleKind.smokePollution: return l10n.moduleTitle_SmokePollutionModuleProperties;
        case GridPreviewModuleKind.manholePipeline: return l10n.moduleTitle_ManholePipelineModuleProperties;
        case GridPreviewModuleKind.renaissance: return l10n.moduleTitle_RenaiModuleProperties;
        case GridPreviewModuleKind.roofProperties: return l10n.moduleTitle_RoofProperties;
        case GridPreviewModuleKind.tunnelDefend: return l10n.moduleTitle_TunnelDefendModuleProperties;
        case GridPreviewModuleKind.gulliverTunnel: return l10n.moduleTitle_InitialGridItemGulliverTunnelProperties;
      }
    }

    final mainSelector = kinds.length > 1
        ? ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
        ...ScrollConfiguration.of(context).dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
      }),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4, left: 4, right: 4),
            child: SegmentedButton<GridPreviewModuleKind>(
              style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
              segments: kinds.map((kind) {
                return ButtonSegment<GridPreviewModuleKind>(
                  value: kind,
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(kindLabel(kind)),
                  ),
                );
              }).toList(),
              selected: {selectedKind},
              onSelectionChanged: (set) {
                final firstOfKind = categories.firstWhere((c) => c.kind == set.first);
                setState(() => _gridItemCategoryKey = firstOfKind.key);
              },
              showSelectedIcon: false,
            ),
          ),
        ),
      ),
    )
        : null;

    final optionsForKind = categories.where((c) => c.kind == selectedKind).toList();
    Widget? subSelector;
    final isWaveModule = selectedKind == GridPreviewModuleKind.armrack ||
        selectedKind == GridPreviewModuleKind.energyGrid;

    if (optionsForKind.length > 1 || isWaveModule) {
      subSelector = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: optionsForKind.map((option) {
              String label = option.wave != null
                  ? '${l10n.waveLabel} ${option.wave}'
                  : option.label;
              return ButtonSegment<String>(
                value: option.key,
                label: Text(label),
              );
            }).toList(),
            selected: {activeGridKey},
            onSelectionChanged: (set) =>
                setState(() => _gridItemCategoryKey = set.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mainSelector != null) mainSelector,
        if (subSelector != null) subSelector,
        if (selectedOption?.wave != null &&
            (selectedOption!.wave ?? 1) > gridOverrideInitialWave)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.gridOverrideModuleWaveSpawnNote(
                waveGeneratorWaveForModuleWave(selectedOption.wave!) ??
                    selectedOption.wave! - 1,
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }


  Widget _buildLawnGrid(
      int rows,
      int cols,
      Color baseColor,
      List<GridPreviewCategoryOption> gridCategories,
      String activeGridKey,
      int activeTabIndex,
      ) {
    final borderColor = baseColor.withValues(alpha: 0.6);

    if (activeTabIndex == 2) {
      final category = _selectedGridCategory(gridCategories, activeGridKey);
      if (category != null) {
        return _buildGridItemCategoryGrid(rows, cols, borderColor, category);
      }
    }

    final data = _getGridData(activeTabIndex);
    return _buildIconLawnGrid(rows, cols, borderColor, data, activeTabIndex);
  }

  Widget _buildIconLawnGrid(
      int rows,
      int cols,
      Color borderColor,
      Map<String, String> data,
      int activeTabIndex,
      ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: AspectRatio(
          aspectRatio: cols / rows,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              children: List.generate(rows, (y) => Expanded(
                child: Row(
                  children: List.generate(cols, (x) {
                    final id = data['$x,$y'];
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: id != null ? _getIconForId(id, activeTabIndex, isGrid: true) : null,
                      ),
                    );
                  }),
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItemCategoryGrid(
      int rows,
      int cols,
      Color borderColor,
      GridPreviewCategoryOption category,
      ) {
    switch (category.kind) {
      case GridPreviewModuleKind.common:
        return _buildIconLawnGrid(rows, cols, borderColor, _getCommonGridData(), 2);
      case GridPreviewModuleKind.piratePlank:
        return _buildPiratePlankGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.railcart:
        return _buildRailcartGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.mechanismPlank:
        return _buildMechanismPlankGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.armrack:
        return _buildArmrackGrid(rows, cols, borderColor, category.wave ?? gridOverrideInitialWave);
      case GridPreviewModuleKind.energyGrid:
        return _buildEnergyGridPreview(rows, cols, borderColor, category.wave ?? gridOverrideInitialWave);
      case GridPreviewModuleKind.bronzeStatue:
        return _buildBronzeStatueGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.powerTile:
        return _buildPowerTileGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.fogSystem:
        return _buildWarMistGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.tideSystem:
        return _buildTideGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.smokePollution:
        return _buildSmokeGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.manholePipeline:
        return _buildManholeGrid(rows, cols, borderColor, category);
      case GridPreviewModuleKind.renaissance:
        return _buildRenaiGrid(rows, cols, borderColor, category);
      case GridPreviewModuleKind.roofProperties:
        return _buildRoofGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.tunnelDefend:
        return _buildTunnelDefendGrid(rows, cols, borderColor);
      case GridPreviewModuleKind.gulliverTunnel:
        return _buildGulliverGrid(rows, cols, borderColor);
    }
  }

  Widget _buildCompositeLawnGrid({
    required int rows,
    required int cols,
    required Color borderColor,
    double? aspectRatio,
    required Widget? Function(int col, int row) cellBuilder,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: AspectRatio(
          aspectRatio: aspectRatio ?? (cols / rows),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              children: List.generate(rows, (row) => Expanded(
                child: Row(
                  children: List.generate(cols, (col) => Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor.withValues(alpha: 0.2), width: 0.5),
                      ),
                      child: cellBuilder(col, row),
                    ),
                  )),
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPiratePlankGrid(int rows, int cols, Color borderColor) {
    final plankRows = readPiratePlankModuleData(widget.levelFile)?.plankRows ?? const <int>[];
    final plankSet = plankRows.toSet();
    return _buildCompositeLawnGrid(
      rows: rows,
      cols: cols,
      borderColor: borderColor,
      cellBuilder: (col, row) {
        if (!plankSet.contains(row)) return null;
        if (col < cols - 4) return null;
        return Container(
          color: const Color(0xFF6D4C41).withValues(alpha: 0.55),
        );
      },
    );
  }

  Widget _buildRailcartGrid(int rows, int cols, Color borderColor) {
    const railsAsset = 'assets/images/others/rails.webp';
    const cartsAsset = 'assets/images/others/railcarts.webp';
    final data = readRailcartModuleData(widget.levelFile);
    if (data == null) return _buildCompositeLawnGrid(rows: rows, cols: cols, borderColor: borderColor, cellBuilder: (_, __) => null);
    final railsGrid = buildRailcartRailsGrid(data, rows, cols);
    final cartSet = buildRailcartCartSet(data);
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        final hasRail = railsGrid[col][row];
        final hasCart = cartSet.contains('$col,$row');
        if (!hasRail && !hasCart) return null;
        return Stack(alignment: Alignment.center, children: [
          if (hasRail) Positioned.fill(child: Opacity(opacity: 0.85, child: AssetImageWidget(assetPath: railsAsset, altCandidates: imageAltCandidates(railsAsset), fit: BoxFit.cover))),
          if (hasCart) Positioned.fill(child: Center(child: Transform.scale(scale: 0.9, child: AssetImageWidget(assetPath: cartsAsset, altCandidates: imageAltCandidates(cartsAsset), fit: BoxFit.contain)))),
        ]);
      },
    );
  }

  Widget _buildMechanismPlankGrid(int rows, int cols, Color borderColor) {
    const railsAsset = 'assets/images/others/kongfu_minecart_tracks.webp';
    const cartLeftAsset = 'assets/images/others/kongfu_minecart_left.webp';
    const cartMiddleAsset = 'assets/images/others/kongfu_minecart_middle.webp';
    const cartRightAsset = 'assets/images/others/kongfu_minecart_right.webp';
    final state = buildMechanismPlankPreviewState(readMechanismPlankModuleData(widget.levelFile));
    if (state == null) return _buildCompositeLawnGrid(rows: rows, cols: cols, borderColor: borderColor, cellBuilder: (_, __) => null);
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        final hasRail = state.hasRailAt(col, row);
        final hasCart = state.hasCartAt(col, row);
        if (!hasRail && !hasCart) return null;
        final cartAsset = state.cartAssetKind(col) == 'left' ? cartLeftAsset : (state.cartAssetKind(col) == 'right' ? cartRightAsset : cartMiddleAsset);
        return Stack(alignment: Alignment.center, children: [
          if (hasRail) Positioned.fill(child: Opacity(opacity: 0.85, child: AssetImageWidget(assetPath: railsAsset, altCandidates: imageAltCandidates(railsAsset), fit: BoxFit.cover))),
          if (hasCart) Positioned.fill(child: Center(child: Transform.scale(scale: 0.9, child: AssetImageWidget(assetPath: cartAsset, altCandidates: imageAltCandidates(cartAsset), fit: BoxFit.contain)))),
        ]);
      },
    );
  }

  Widget _buildArmrackGrid(int rows, int cols, Color borderColor, int wave) {
    final items = armrackItemsForModuleWave(readArmrackModuleData(widget.levelFile), wave);
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        final item = items.firstWhereOrNull((e) => e.mX == col && e.mY == row);
        if (item == null) return null;
        final asset = armrackIconAsset(item.type);
        final scale = armrackGridScale(item.type);
        return LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth * scale;
          final h = constraints.maxHeight * scale;
          return Align(alignment: Alignment.bottomCenter, child: SizedBox(width: w, height: h, child: AssetImageWidget(assetPath: asset, width: w, height: h, fit: BoxFit.contain)));
        });
      },
    );
  }

  Widget _buildEnergyGridPreview(int rows, int cols, Color borderColor, int wave) {
    const tileAsset = 'assets/images/griditems/energyGrid.webp';
    final items = energyGridItemsForModuleWave(readEnergyGridModuleData(widget.levelFile), wave);
    final tileSet = items.map((e) => '${e.mX},${e.mY}').toSet();
    return _buildCompositeLawnGrid(
      rows: rows, cols: cols, borderColor: borderColor,
      cellBuilder: (col, row) {
        if (!tileSet.contains('$col,$row')) return null;
        return LayoutBuilder(builder: (context, constraints) {
          const scale = 0.92;
          final w = constraints.maxWidth * scale;
          final h = constraints.maxHeight * scale;
          return Align(alignment: Alignment.bottomCenter, child: SizedBox(width: w, height: h, child: AssetImageWidget(assetPath: tileAsset, width: w, height: h, fit: BoxFit.contain)));
        });
      },
    );
  }

  Map<String, String> _getGridData(int activeTabIndex) {
    if (activeTabIndex == 2) return _getCommonGridData();
    return _getPlacementGridData(activeTabIndex);
  }

  Map<String, String> _getCommonGridData() {
    final result = <String, String>{};
    for (var obj in widget.levelFile.objects) {
      if (obj.objClass != 'InitialGridItemProperties') continue;
      final data = obj.objData;
      if (data is Map) _addPlacementsToGrid(result, data['InitialGridItemPlacements'] ?? data['GridItems'], 'TypeName');
    }
    return result;
  }

  Map<String, String> _getPlacementGridData(int activeTabIndex) {
    final result = <String, String>{};
    for (var obj in widget.levelFile.objects) {
      final data = obj.objData;
      if (data is! Map) continue;
      if (activeTabIndex == 0) {
        if (_plantTypeIndex == 0) {
          if (obj.objClass == 'InitialPlantEntryProperties') _addPlacementsToGrid(result, data['Plants'] ?? data['Placements'], 'TypeName');
        } else {
          if (obj.objClass == 'InitialPlantProperties' || obj.objClass == 'FrozenPlantPlacement') _addPlacementsToGrid(result, data['InitialPlantPlacements'] ?? data['InitialPlantList'], 'PlantType');
        }
      } else if (activeTabIndex == 1 && obj.objClass == 'InitialZombieProperties') {
        _addPlacementsToGrid(result, data['InitialZombiePlacements'] ?? data['Zombies'], 'TypeName');
      }
    }
    return result;
  }

  void _addPlacementsToGrid(Map<String, String> result, dynamic list, String typeKey) {
    if (list is! List) return;
    for (var e in list) {
      if (e is! Map) continue;
      final dynamic rawX = e['GridX'] ?? e['gridX'] ?? e['mX'] ?? e['X'];
      final dynamic rawY = e['GridY'] ?? e['gridY'] ?? e['mY'] ?? e['Y'];
      dynamic rawType = e[typeKey] ?? e['TypeName'] ?? e['PlantType'] ?? e['ZombieType'];
      if (rawType == null && e['PlantTypes'] is List && (e['PlantTypes'] as List).isNotEmpty) rawType = (e['PlantTypes'] as List).first;
      if (rawX != null && rawY != null && rawType is String) {
        final x = _parseCoord(rawX);
        final y = _parseCoord(rawY);
        result['$x,$y'] = _cleanId(rawType);
      }
    }
  }

  Widget _getIconForId(String id, int activeTabIndex, {bool isGrid = false}) {
    if (id.isEmpty) return const SizedBox.shrink();
    final clean = _cleanId(id);

    if (ToolRepository.get(clean) != null) {
      return _ToolIcon(id: clean, isGrid: isGrid);
    }
    if (ZombieRepository().getZombieById(clean) != null) {
      return _ZombieIcon(id: clean, isGrid: isGrid);
    }
    if (PlantRepository().getPlantInfoById(clean) != null) {
      return _PlantIcon(id: clean, isGrid: isGrid);
    }

    return _GridItemIcon(id: clean, isGrid: isGrid);
  }


  Widget _buildEncounterCard(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final Set<String> zombies = {};
    final Set<String> events = {};
    bool hasWaveModule = widget.levelFile.objects.any((o) => o.objClass == 'WaveManagerModuleProperties' || o.objClass == 'WaveManagerProperties' || o.objClass == 'WaveGeneratorProperties');
    final wm = widget.parsed.waveManager;
    if (wm is WaveManagerData) {
      for (var wave in wm.waves) {
        for (var rtid in wave) {
          final alias = LevelParser.extractAlias(rtid);
          final obj = widget.parsed.objectMap[alias];
          if (obj != null) {
            events.add(obj.objClass.replaceAll('WaveActionProps', ''));
            _extractZombiesFromData(obj.objData, zombies);
          }
        }
      }
    }
    final wg = widget.parsed.waveGenerator;
    if (wg != null) {
      for (var wave in wg.waves) {
        for (var z in wave.zombies) {
          if (z.type.isNotEmpty) zombies.add(_cleanId(z.type));
        }
      }
    }
    if (!hasWaveModule && zombies.isEmpty && events.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.previewZombiesAndEvents, theme),
            if (zombies.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: zombies.map((id) => _ZombieIcon(id: id, size: 36)).toList()),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 6, children: events.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)).toList()),
            ],
          ],
        ),
      ),
    );
  }

  void _extractZombiesFromData(dynamic data, Set<String> out) {
    if (data is Map) {
      final t = data['TypeName'] ?? data['ZombieType'] ?? data['Type'];
      if (t is String && t.isNotEmpty) out.add(_cleanId(t));
      for (var v in data.values) { _extractZombiesFromData(v, out); }
    } else if (data is List) {
      for (var e in data) { _extractZombiesFromData(e, out); }
    }
  }

  Widget _buildModulesCard(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final challenges = widget.levelFile.objects.where((o) => o.objClass == 'StarChallengeModuleProperties').toList();
    final themesObj = widget.levelFile.objects.firstWhereOrNull((o) => o.objClass == 'RiftThemeDemoModuleProperties');
    final themes = ((themesObj?.objData as Map?)?['Themes'] as List?)?.cast<String>() ?? [];
    if (challenges.isEmpty && themes.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.previewChallengesAndThemes, theme),
            if (challenges.isNotEmpty) ...[
              ...challenges.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [const Icon(Icons.star, size: 16, color: Colors.amber), const SizedBox(width: 10), Text(c.aliases?.first ?? 'Challenge', style: const TextStyle(fontSize: 15))]),
              )),
            ],
            if (themes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: themes.map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.blue.withValues(alpha: 0.15))).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon; final String label; final Color color; final String? tooltip;
  const _ResourceChip({required this.icon, required this.label, required this.color, this.tooltip});
  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold))]),
    );
    if (tooltip != null) content = Tooltip(message: tooltip!, child: content);
    return content;
  }
}

class _UniversalIcon extends StatelessWidget {
  final String id; final double size;
  const _UniversalIcon({required this.id, required this.size});
  @override
  Widget build(BuildContext context) {
    if (PlantRepository().getPlantInfoById(id) != null) return _PlantIcon(id: id, size: size);
    if (ZombieRepository().getZombieById(id) != null) return _ZombieIcon(id: id, size: size);
    if (ToolRepository.get(id) != null) return _ToolIcon(id: id, size: size);

    return _GridItemIcon(id: id, size: size);
  }
}

class _ToolIcon extends StatelessWidget {
  final String id; final double size; final bool isGrid;
  const _ToolIcon({required this.id, this.size = 42, this.isGrid = false});
  @override
  Widget build(BuildContext context) {
    final info = ToolRepository.get(id);
    final tooltip = ToolRepository.localizedName(context, id);
    final asset = info?.icon != null ? 'assets/images/tools/${info!.icon}' : null;

    if (isGrid) {
      return Tooltip(
        message: tooltip,
        child: asset != null
            ? AssetImageWidget(assetPath: asset, fit: BoxFit.contain)
            : Icon(Icons.build, size: size, color: Colors.white24),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: asset != null
            ? AssetImageWidget(assetPath: asset, fit: BoxFit.contain)
            : Center(child: Icon(Icons.build, size: size/2, color: Colors.white24)),
      ),
    );
  }
}

class _ConveyorBadgeIcon extends StatelessWidget {
  final String id; final int wave; final bool isAdd;
  const _ConveyorBadgeIcon({required this.id, required this.wave, required this.isAdd});
  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      _UniversalIcon(id: id, size: 40),
      Positioned(top: -4, right: -4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: isAdd ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24, width: 0.5)), child: Text('$wave', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))),
    ]);
  }
}

class _PlantIcon extends StatelessWidget {
  final String id; final double size; final bool isGrid;
  const _PlantIcon({required this.id, this.size = 42, this.isGrid = false});
  @override
  Widget build(BuildContext context) {
    final info = PlantRepository().getPlantInfoById(id);
    final asset = info?.iconAssetPath;
    final tooltip = ResourceNames.lookup(context, info?.name ?? id);

    if (isGrid) {
      return Tooltip(
        message: tooltip,
        child: asset != null
            ? AssetImageWidget(assetPath: asset, fit: BoxFit.contain)
            : Icon(Icons.help_outline, size: size, color: Colors.white24),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: asset != null
            ? AssetImageWidget(assetPath: asset, fit: BoxFit.contain)
            : Center(child: Icon(Icons.help_outline, size: size/2, color: Colors.white24)),
      ),
    );
  }
}

class _ZombieIcon extends StatelessWidget {
  final String id; final double size; final bool isGrid;
  const _ZombieIcon({required this.id, this.size = 42, this.isGrid = false});
  @override
  Widget build(BuildContext context) {
    final info = ZombieRepository().getZombieById(id);
    final tooltip = ZombieRepository().getName(id);
    final asset = info?.icon != null ? 'assets/images/zombies/${info!.icon}' : null;

    if (isGrid) {
      return Tooltip(
        message: tooltip,
        child: asset != null
            ? AssetImageWidget(assetPath: asset, fit: BoxFit.contain)
            : Icon(Icons.person, size: size, color: Colors.white24),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: asset != null
            ? AssetImageWidget(assetPath: asset, fit: BoxFit.contain)
            : Center(child: Icon(Icons.person, size: size/2, color: Colors.white24)),
      ),
    );
  }
}

class _GridItemIcon extends StatelessWidget {
  final String id; final double size; final bool isGrid;
  const _GridItemIcon({required this.id, this.size = 42, this.isGrid = false});
  @override
  Widget build(BuildContext context) {
    final path = GridItemRepository.getIconPath(id);

    if (isGrid) {
      return Tooltip(
        message: id,
        child: AssetImageWidget(assetPath: path, fit: BoxFit.contain),
      );
    }

    return Tooltip(
      message: id,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: AssetImageWidget(assetPath: path, fit: BoxFit.contain),
      ),
    );
  }
}