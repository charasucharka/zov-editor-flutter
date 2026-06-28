/// Asset paths for tag icons under [assets/images/tags/].
abstract class TagAssets {
  TagAssets._();

  static const _base = 'assets/images/tags';

  static String plantRarity(String fileName) => '$_base/plants/rarity/$fileName';

  static String plantRole(String fileName) => '$_base/plants/role/$fileName';

  static String attribute(String fileName) => '$_base/attributes/$fileName';

  static String zombieType(String fileName) => '$_base/zombies/type/$fileName';

  static const attributeIcons = <String?>[
    null,
    '$_base/attributes/Physics.webp',
    '$_base/attributes/Poison.webp',
    '$_base/attributes/Electric.webp',
    '$_base/attributes/Magic.webp',
    '$_base/attributes/Ice.webp',
    '$_base/attributes/Fire.webp',
  ];
}
