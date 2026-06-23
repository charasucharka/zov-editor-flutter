import 'package:flutter/material.dart';
import 'package:c_editor/data/models/stage_catalog.dart';
import 'package:c_editor/data/repository/stage_catalog_repository.dart';
import 'package:c_editor/l10n/app_localizations.dart';
import 'package:c_editor/l10n/resource_names.dart';
import 'package:c_editor/utils/selection_search.dart';
import 'package:c_editor/widgets/asset_image.dart'
    show AssetImageWidget, imageAltCandidates;
import 'package:c_editor/widgets/editor_components.dart';

/// Pick the source stage implementation for a level-local custom lawn.
class StageBaseSelectionScreen extends StatefulWidget {
  const StageBaseSelectionScreen({
    super.key,
    required this.onStageBaseSelected,
    required this.onBack,
  });

  final void Function(StageBaseOption option) onStageBaseSelected;
  final VoidCallback onBack;

  @override
  State<StageBaseSelectionScreen> createState() =>
      _StageBaseSelectionScreenState();
}

class _StageBaseSelectionScreenState extends State<StageBaseSelectionScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    var items = StageCatalogRepository.stageBaseOptions();
    if (normalizeSelectionSearchQuery(_searchQuery).isNotEmpty) {
      items = items.where((option) {
        final nameKey = _stageNameKey(option.alias);
        final name = ResourceNames.lookup(context, nameKey);
        return matchesSelectionSearch(_searchQuery, [
          name,
          nameKey,
          option.alias,
          option.objclass,
          option.backgroundImagePrefix ?? '',
          option.backgroundResourceGroup ?? '',
        ]);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text(l10n?.selectCustomStageBase ?? 'Select base lawn'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SelectionSearchField(
              hintText: 'Search by lawn name or codename',
              query: _searchQuery,
              onChanged: (v) => setState(() => _searchQuery = v),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No lawn found',
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.88,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final option = items[i];
                      final displayName = ResourceNames.lookup(
                        context,
                        _stageNameKey(option.alias),
                      );
                      final iconPath =
                          'assets/images/round_icons/${option.iconName}';
                      return Card(
                        child: InkWell(
                          onTap: () => widget.onStageBaseSelected(option),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: AssetImageWidget(
                                      assetPath: iconPath,
                                      altCandidates: imageAltCandidates(
                                        iconPath,
                                      ),
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  option.alias,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _stageNameKey(String alias) => 'stage_$alias';
}
