import 'package:flutter_test/flutter_test.dart';
import 'package:c_editor/data/pvz_models.dart';
import 'package:c_editor/data/repository/grid_item_repository.dart';

void main() {
  setUp(GridItemRepository.staticItems.clear);
  tearDown(GridItemRepository.staticItems.clear);

  test('builds default grid item references against GridItemTypes', () {
    GridItemRepository.staticItems.add(
      const GridItemInfo(
        typeName: 'gravestone_egypt',
        category: GridItemCategory.scene,
      ),
    );
    final levelFile = PvzLevelFile(objects: []);

    final rtid = GridItemRepository.buildGridItemTypeRtid(
      'gravestone_egypt',
      levelFile,
    );

    expect(rtid, 'RTID(gravestone@GridItemTypes)');
    expect(levelFile.objects, isEmpty);
  });

  test('builds custom grid item references against CurrentLevel once', () {
    GridItemRepository.staticItems.add(
      GridItemInfo(
        typeName: 'armrack',
        category: GridItemCategory.scene,
        source: GridItemSource.custom,
        gridItemType: PvzObject(
          aliases: ['armrack'],
          objClass: 'GridItemType',
          objData: {
            'TypeName': 'armrack',
            'GridItemClass': 'GridItemArmrack',
            'Properties': 'RTID(GridItemArmrackDefault@PropertySheets)',
          },
        ),
      ),
    );
    final levelFile = PvzLevelFile(objects: []);

    final firstRtid = GridItemRepository.buildGridItemTypeRtid(
      'armrack',
      levelFile,
    );
    final secondRtid = GridItemRepository.buildGridItemTypeRtid(
      'armrack',
      levelFile,
    );

    expect(firstRtid, 'RTID(armrack@CurrentLevel)');
    expect(secondRtid, firstRtid);
    expect(levelFile.objects, hasLength(1));
    expect(levelFile.objects.single.aliases, ['armrack']);
    expect(levelFile.objects.single.objClass, 'GridItemType');
    expect(levelFile.objects.single.objData, {
      'TypeName': 'armrack',
      'GridItemClass': 'GridItemArmrack',
      'Properties': 'RTID(GridItemArmrackDefault@PropertySheets)',
    });
  });
}
