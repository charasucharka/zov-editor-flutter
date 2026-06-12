import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:c_editor/data/grid_override_module_utils.dart';
import 'package:c_editor/data/level_parser.dart';
import 'package:c_editor/data/pvz_models.dart';
import 'package:c_editor/data/repository/zombie_repository.dart';
import 'package:c_editor/data/rtid_parser.dart';
import 'package:c_editor/l10n/app_localizations.dart';
import 'package:c_editor/l10n/resource_names.dart';
import 'package:c_editor/theme/app_theme.dart';
import 'package:c_editor/widgets/asset_image.dart'
    show AssetImageWidget, imageAltCandidates;
import 'package:c_editor/widgets/editor_components.dart';
import 'package:c_editor/widgets/grid_override_wave_groups_bar.dart';

/// Kongfu World bronze statue (铜人阵) placement editor.

/// Shared height so [AddItemCard] aligns with [_BronzeStatueCard] in the wrap.
const double _kBronzeStatueCardHeight = 175;

class BronzeModuleScreen extends StatefulWidget {
  const BronzeModuleScreen({
    super.key,
    required this.rtid,
    required this.levelFile,
    required this.onChanged,
    required this.onBack,
  });

  final String rtid;
  final PvzLevelFile levelFile;
  final VoidCallback onChanged;
  final VoidCallback onBack;

  @override
  State<BronzeModuleScreen> createState() => _BronzeModuleScreenState();
}

String _zombieIdForBronzeKind(BronzeStatueKind kind) {
  switch (kind) {
    case BronzeStatueKind.strength:
      return 'kongfu_strong_bronze';
    case BronzeStatueKind.mage:
      return 'kongfu_magic_bronze';
    case BronzeStatueKind.agile:
      return 'kongfu_agile_bronze';
  }
}

class _BronzeItemRef {
  const _BronzeItemRef({required this.batchIndex, required this.itemIndex});

  final int batchIndex;
  final int itemIndex;
}

class _BronzeModuleScreenState extends State<BronzeModuleScreen> {
  late PvzObject _moduleObj;
  late BronzePropertiesData _data;
  int _selectedIndex = -1;
  int _selectedX = 0;
  int _selectedY = 0;
  _BronzeItemRef? _itemToDelete;
  BronzeStatueBatchData? _batchToDelete;

  int get _gridRows {
    final (rows, _) = LevelParser.getGridDimensionsFromFile(widget.levelFile);
    return rows;
  }

  int get _gridCols {
    final (_, cols) = LevelParser.getGridDimensionsFromFile(widget.levelFile);
    return cols;
  }

  BronzeStatueBatchData? get _selectedBatch {
    if (_selectedIndex < 0 || _selectedIndex >= _data.data.length) {
      return null;
    }
    return _data.data[_selectedIndex];
  }

  List<_IndexedBronzeItem> get _selectedBatchItemsIndexed {
    final batch = _selectedBatch;
    if (batch == null) return [];
    return [
      for (var i = 0; i < batch.itemList.length; i++)
        _IndexedBronzeItem(
          batchIndex: _selectedIndex,
          itemIndex: i,
          item: batch.itemList[i],
        ),
    ];
  }

  List<_IndexedBronzeItem> get _allItemsIndexed {
    final out = <_IndexedBronzeItem>[];
    for (var b = 0; b < _data.data.length; b++) {
      final batch = _data.data[b];
      for (var i = 0; i < batch.itemList.length; i++) {
        out.add(
          _IndexedBronzeItem(
            batchIndex: b,
            itemIndex: i,
            item: batch.itemList[i],
          ),
        );
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    if (_data.data.isNotEmpty) {
      _selectedIndex = 0;
    }
  }

  void _loadData() {
    final info = RtidParser.parse(widget.rtid);
    final alias = info?.alias ?? 'Bronze';
    _moduleObj = widget.levelFile.objects.firstWhere(
      (o) => o.aliases?.contains(alias) == true,
      orElse: () => PvzObject(
        aliases: [alias],
        objClass: 'BronzeProperties',
        objData: BronzePropertiesData().toJson(),
      ),
    );
    if (!widget.levelFile.objects.contains(_moduleObj)) {
      widget.levelFile.objects.add(_moduleObj);
    }
    try {
      _data = BronzePropertiesData.fromJson(
        Map<String, dynamic>.from(_moduleObj.objData as Map),
      );
    } catch (_) {
      _data = BronzePropertiesData();
    }
  }

  void _sync() {
    _moduleObj.objData = _data.toJson();
    widget.onChanged();
    setState(() {});
  }

  void _syncBatches(List<BronzeStatueBatchData> batches) {
    _data = BronzePropertiesData(data: batches, shakeOffset: _data.shakeOffset);
    _sync();
  }

  void _addBatch() {
    final newBatch = BronzeStatueBatchData(
      wave: _data.data.isEmpty
          ? gridOverrideFirstWave
          : _data.data.last.wave + 1,
    );
    _syncBatches([..._data.data, newBatch]);
    setState(() => _selectedIndex = _data.data.length - 1);
  }

  void _deleteBatch(BronzeStatueBatchData target) {
    _syncBatches(_data.data.where((e) => e != target).toList());
    if (_selectedIndex >= _data.data.length) {
      _selectedIndex = _data.data.isEmpty ? -1 : _data.data.length - 1;
    }
  }

  void _updateSelectedBatch(BronzeStatueBatchData updated) {
    if (_selectedIndex < 0 || _selectedIndex >= _data.data.length) return;
    final list = List<BronzeStatueBatchData>.from(_data.data);
    list[_selectedIndex] = updated;
    _syncBatches(list);
  }

  void _replaceItemAt(_BronzeItemRef ref, BronzeStatueItemData next) {
    final batches = List<BronzeStatueBatchData>.from(_data.data);
    if (ref.batchIndex < 0 || ref.batchIndex >= batches.length) return;
    final batch = batches[ref.batchIndex];
    final items = List<BronzeStatueItemData>.from(batch.itemList);
    if (ref.itemIndex < 0 || ref.itemIndex >= items.length) return;
    items[ref.itemIndex] = next;
    batches[ref.batchIndex] = BronzeStatueBatchData(
      wave: batch.wave,
      itemList: items,
    );
    _syncBatches(batches);
  }

  void _deleteItem(_BronzeItemRef ref) {
    final batches = List<BronzeStatueBatchData>.from(_data.data);
    if (ref.batchIndex < 0 || ref.batchIndex >= batches.length) return;
    final batch = batches[ref.batchIndex];
    final items = List<BronzeStatueItemData>.from(batch.itemList)
      ..removeAt(ref.itemIndex);
    if (items.isEmpty) {
      batches.removeAt(ref.batchIndex);
      if (_selectedIndex >= batches.length) {
        _selectedIndex = batches.isEmpty ? -1 : batches.length - 1;
      }
    } else {
      batches[ref.batchIndex] = BronzeStatueBatchData(
        wave: batch.wave,
        itemList: items,
      );
    }
    _syncBatches(batches);
  }

  void _addBronze(BronzeStatueKind kind) {
    if (_selectedBatch == null) {
      final item = BronzeStatueItemData(
        mX: _selectedX,
        mY: _selectedY,
        spawnTime: 60,
        kind: kind,
      );
      _syncBatches([
        ..._data.data,
        BronzeStatueBatchData(
          wave: gridOverrideFirstWave,
          itemList: [item],
        ),
      ]);
      setState(() => _selectedIndex = _data.data.length - 1);
      return;
    }
    final batch = _selectedBatch!;
    final item = BronzeStatueItemData(
      mX: _selectedX,
      mY: _selectedY,
      spawnTime: 60,
      kind: kind,
    );
    _updateSelectedBatch(
      BronzeStatueBatchData(
        wave: batch.wave,
        itemList: [...batch.itemList, item],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = l10n?.bronzeModuleTitle ?? 'Bronze Properties';
    final helpTitle = l10n?.bronzeModuleHelpTitle ?? 'Bronze Properties';
    final selected = _selectedBatch;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n?.back ?? 'Back',
          onPressed: widget.onBack,
        ),
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n?.tooltipAboutModule ?? 'About this module',
            onPressed: () => showEditorHelpDialog(
              context,
              title: helpTitle,
              sections: [
                HelpSectionData(
                  title: l10n?.bronzeModuleHelpOverview ?? 'Overview',
                  body:
                      l10n?.bronzeModuleHelpOverviewBody ??
                      'Places Han, Qigong, and Knight bronze statues on the lawn.',
                ),
                HelpSectionData(
                  title: l10n?.bronzeModuleHelpBatches ?? 'Revival logic',
                  body:
                      l10n?.bronzeModuleHelpBatchesBody ??
                      'Each wave group is one entry in the level file. '
                          'Revival timing uses spawn time (seconds). '
                          'Statues in the same group with the same spawn time revive together.',
                ),
                HelpSectionData(
                  title:
                      l10n?.bronzeModuleHelpWaveLimit ?? 'Wave limit',
                  body:
                      l10n?.bronzeModuleHelpWaveLimitBody ??
                      'Due to a game limitation, only wave 1 entries take effect in-game. '
                          'Other wave groups can still be edited and are saved to the level file, '
                          'but only wave 1 appears in the wave timeline tab.',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: kGridOverrideModuleSectionPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.bronzeModuleShakeOffset ??
                              'Revival shake offset',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 160,
                          child: TextFormField(
                            initialValue: _data.shakeOffset.toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  l10n?.bronzeModuleShakeOffsetLabel ??
                                  'Shake offset',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final n = double.tryParse(v);
                              if (n != null) {
                                _data = BronzePropertiesData(
                                  data: _data.data,
                                  shakeOffset: n,
                                );
                                _sync();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.gridOverrideModuleAppearances ?? 'Wave groups',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GridOverrideWaveGroupsBar(
                  itemCount: _data.data.length,
                  selectedIndex: _selectedIndex,
                  onSelected: (idx) => setState(() => _selectedIndex = idx),
                  onDeleteAt: (idx) => setState(
                    () => _batchToDelete = _data.data[idx],
                  ),
                  onAdd: _addBatch,
                  groupLabel: (idx) =>
                      '${l10n?.airDropShipGroupLabel ?? "Group"} ${idx + 1}',
                ),
                if (selected != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    key: ValueKey('bronze_panel_$_selectedIndex'),
                    child: Padding(
                      padding: kGridOverrideModuleSectionPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n?.appearanceLabel ?? "Appearance"} ${_selectedIndex + 1}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: '${selected.wave}',
                            decoration: InputDecoration(
                              labelText:
                                  l10n?.gridOverrideModuleWaveFieldOneBased ??
                                  'Wave (1 = first wave)',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n >= 1) {
                                _updateSelectedBatch(
                                  BronzeStatueBatchData(
                                    wave: n,
                                    itemList: selected.itemList,
                                  ),
                                );
                              }
                            },
                          ),
                          if (selected.wave != gridOverrideFirstWave) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n?.gridOverrideModuleTimelineNote ??
                                  'Only wave 1 entries appear in the wave timeline tab.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.selectedPosition ??
                                        'Selected position',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'R${_selectedY + 1} : C${_selectedX + 1}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          scaleTableForDesktop(
                            context: context,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: AspectRatio(
                                aspectRatio: _gridCols / _gridRows,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? const Color(0xFF31383B)
                                        : const Color(0xFFD7ECF1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF6B899A),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: List.generate(_gridRows, (row) {
                                      return Expanded(
                                        child: Row(
                                          children: List.generate(_gridCols, (
                                            col,
                                          ) {
                                            final isSelected =
                                                row == _selectedY &&
                                                col == _selectedX;
                                            final cellItems =
                                                _selectedBatchItemsIndexed
                                                    .where(
                                                      (e) =>
                                                          e.item.mX == col &&
                                                          e.item.mY == row,
                                                    )
                                                    .toList();
                                            final firstItem =
                                                cellItems.firstOrNull;
                                            final count = cellItems.length;
                                            return Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() {
                                                  _selectedX = col;
                                                  _selectedY = row;
                                                }),
                                                child: Container(
                                                  margin: const EdgeInsets.all(
                                                    0.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.2,
                                                              )
                                                        : Colors.transparent,
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : const Color(
                                                              0xFF6B899A,
                                                            ),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child:
                                                      count > 0 &&
                                                          firstItem != null
                                                      ? Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            Positioned.fill(
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      2,
                                                                    ),
                                                                child: FittedBox(
                                                                  fit: BoxFit
                                                                      .contain,
                                                                  child: _BronzeZombieIcon(
                                                                    kind:
                                                                        firstItem
                                                                            .item
                                                                            .kind,
                                                                    size: 38,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            if (count > 1)
                                                              Positioned(
                                                                top: 3,
                                                                right: 3,
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            3,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .onSurfaceVariant,
                                                                    borderRadius:
                                                                        const BorderRadius.only(
                                                                          bottomLeft:
                                                                              Radius.circular(
                                                                                6,
                                                                              ),
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    '+${count - 1}',
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.bronzeModuleInCell ??
                                'Bronze statues in selected tile',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._selectedBatchItemsIndexed
                                  .where(
                                    (e) =>
                                        e.item.mX == _selectedX &&
                                        e.item.mY == _selectedY,
                                  )
                                  .map(
                                    (e) => _BronzeStatueCard(
                                      item: e.item,
                                      showCoordinates: false,
                                      onDelete: () => setState(
                                        () => _itemToDelete = _BronzeItemRef(
                                          batchIndex: e.batchIndex,
                                          itemIndex: e.itemIndex,
                                        ),
                                      ),
                                      onSpawnTimeChanged: (t) => _replaceItemAt(
                                        _BronzeItemRef(
                                          batchIndex: e.batchIndex,
                                          itemIndex: e.itemIndex,
                                        ),
                                        BronzeStatueItemData(
                                          mX: e.item.mX,
                                          mY: e.item.mY,
                                          spawnTime: t,
                                          kind: e.item.kind,
                                        ),
                                      ),
                                      deleteTooltip: l10n?.delete ?? 'Delete',
                                    ),
                                  ),
                              AddItemCard(
                                onPressed: () => _showAddBronzeDialog(context),
                                width: 140,
                                minHeight: _kBronzeStatueCardHeight,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_allItemsIndexed.any(
                  (e) =>
                      e.item.mX < 0 ||
                      e.item.mY < 0 ||
                      e.item.mX >= _gridCols ||
                      e.item.mY >= _gridRows,
                )) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n?.outsideLawnItems ?? 'Objects outside the lawn',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allItemsIndexed
                        .where(
                          (e) =>
                              e.item.mX < 0 ||
                              e.item.mY < 0 ||
                              e.item.mX >= _gridCols ||
                              e.item.mY >= _gridRows,
                        )
                        .map(
                          (e) => _BronzeStatueCard(
                            item: e.item,
                            showCoordinates: true,
                            onDelete: () => setState(
                              () => _itemToDelete = _BronzeItemRef(
                                batchIndex: e.batchIndex,
                                itemIndex: e.itemIndex,
                              ),
                            ),
                            onSpawnTimeChanged: (t) => _replaceItemAt(
                              _BronzeItemRef(
                                batchIndex: e.batchIndex,
                                itemIndex: e.itemIndex,
                              ),
                              BronzeStatueItemData(
                                mX: e.item.mX,
                                mY: e.item.mY,
                                spawnTime: t,
                                kind: e.item.kind,
                              ),
                            ),
                            deleteTooltip: l10n?.delete ?? 'Delete',
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (_itemToDelete != null) _buildDeleteItemDialog(),
          if (_batchToDelete != null) _buildDeleteBatchDialog(l10n),
        ],
      ),
    );
  }

  Future<void> _showAddBronzeDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cancelGreen = theme.brightness == Brightness.dark
        ? pvzGreenLight
        : pvzGreenDark;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n?.bronzeModuleAddTitle ?? 'Add bronze type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AddBronzeKindRow(
                  kind: BronzeStatueKind.strength,
                  label: l10n?.bronzeKindStrength ?? 'Han (strong)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _addBronze(BronzeStatueKind.strength);
                  },
                ),
                const SizedBox(height: 16),
                _AddBronzeKindRow(
                  kind: BronzeStatueKind.mage,
                  label: l10n?.bronzeKindMage ?? 'Qigong (mage)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _addBronze(BronzeStatueKind.mage);
                  },
                ),
                const SizedBox(height: 16),
                _AddBronzeKindRow(
                  kind: BronzeStatueKind.agile,
                  label: l10n?.bronzeKindAgile ?? 'Knight (agile)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _addBronze(BronzeStatueKind.agile);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: cancelGreen),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeleteBatchDialog(AppLocalizations? l10n) {
    final target = _batchToDelete!;
    final index = _data.data.indexOf(target);
    return AlertDialog(
      title: Text(l10n?.removeItem ?? 'Remove item'),
      content: Text(
        l10n?.removeItemConfirm(
              '${l10n?.airDropShipGroupLabel ?? "Group"} ${index + 1}',
            ) ??
            'Remove group ${index + 1}?',
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _batchToDelete = null),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        TextButton(
          onPressed: () {
            _deleteBatch(target);
            setState(() => _batchToDelete = null);
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n?.remove ?? 'Remove'),
        ),
      ],
    );
  }

  Widget _buildDeleteItemDialog() {
    final l10n = AppLocalizations.of(context);
    final ref = _itemToDelete!;
    BronzeStatueItemData? item;
    if (ref.batchIndex < _data.data.length) {
      final batch = _data.data[ref.batchIndex];
      if (ref.itemIndex < batch.itemList.length) {
        item = batch.itemList[ref.itemIndex];
      }
    }
    if (item == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _itemToDelete = null);
      });
      return const SizedBox.shrink();
    }
    final zid = _zombieIdForBronzeKind(item.kind);
    final displayName = ResourceNames.lookup(context, 'zombie_$zid');
    final name = displayName != 'zombie_$zid' ? displayName : zid;
    return AlertDialog(
      title: Text(l10n?.removeItem ?? 'Remove item'),
      content: Text(
        l10n?.removeItemConfirm('${item.spawnTime}s $name') ??
            'Remove ${item.spawnTime}s $name?',
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _itemToDelete = null),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        TextButton(
          onPressed: () {
            _deleteItem(ref);
            setState(() => _itemToDelete = null);
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n?.remove ?? 'Remove'),
        ),
      ],
    );
  }
}

class _IndexedBronzeItem {
  const _IndexedBronzeItem({
    required this.batchIndex,
    required this.itemIndex,
    required this.item,
  });

  final int batchIndex;
  final int itemIndex;
  final BronzeStatueItemData item;
}

class _BronzeZombieIcon extends StatelessWidget {
  const _BronzeZombieIcon({required this.kind, this.size = 40});

  final BronzeStatueKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final id = _zombieIdForBronzeKind(kind);
    final path = ZombieRepository().getZombieById(id)?.iconAssetPath;
    if (path == null || path.isEmpty) {
      return Icon(Icons.person, size: size);
    }
    return AssetImageWidget(
      assetPath: path,
      altCandidates: imageAltCandidates(path),
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _AddBronzeKindRow extends StatelessWidget {
  const _AddBronzeKindRow({
    required this.kind,
    required this.label,
    required this.onTap,
  });

  final BronzeStatueKind kind;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              _BronzeZombieIcon(kind: kind, size: 48),
              const SizedBox(width: 16),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BronzeStatueCard extends StatefulWidget {
  const _BronzeStatueCard({
    required this.item,
    required this.showCoordinates,
    required this.onDelete,
    required this.onSpawnTimeChanged,
    required this.deleteTooltip,
  });

  final BronzeStatueItemData item;
  final bool showCoordinates;
  final VoidCallback onDelete;
  final void Function(int spawnTime) onSpawnTimeChanged;
  final String deleteTooltip;

  @override
  State<_BronzeStatueCard> createState() => _BronzeStatueCardState();
}

class _BronzeStatueCardState extends State<_BronzeStatueCard> {
  late TextEditingController _spawnCtrl;

  @override
  void initState() {
    super.initState();
    _spawnCtrl = TextEditingController(text: '${widget.item.spawnTime}');
  }

  @override
  void didUpdateWidget(covariant _BronzeStatueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.spawnTime != widget.item.spawnTime) {
      _spawnCtrl.text = '${widget.item.spawnTime}';
    }
  }

  @override
  void dispose() {
    _spawnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final zid = _zombieIdForBronzeKind(item.kind);
    final displayName = ResourceNames.lookup(context, 'zombie_$zid');
    final name = displayName != 'zombie_$zid' ? displayName : zid;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 140,
        height: _kBronzeStatueCardHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 88,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                    child: Center(
                      child: _BronzeZombieIcon(kind: item.kind, size: 77),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: widget.deleteTooltip,
                      onPressed: widget.onDelete,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize:
                            (theme.textTheme.titleSmall?.fontSize ?? 14) * 1.08,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    if (widget.showCoordinates)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'R${widget.item.mY + 1}:C${widget.item.mX + 1}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    TextField(
                      controller: _spawnCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            l10n?.bronzeModuleSpawnTimeLabel ??
                            'Revival time (s)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 0) {
                          widget.onSpawnTimeChanged(n);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
