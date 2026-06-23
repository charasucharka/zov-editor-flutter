class CustomStagePreset {
  const CustomStagePreset({
    required this.id,
    required this.alias,
    required this.nameKey,
    required this.sourceKey,
    required this.iconName,
    required this.objclass,
    required this.objdata,
  });

  final String id;
  final String alias;
  final String nameKey;
  final String sourceKey;
  final String iconName;
  final String objclass;
  final Map<String, dynamic> objdata;

  factory CustomStagePreset.fromJson(Map<String, dynamic> json) {
    final rawObjdata = json['objdata'];
    return CustomStagePreset(
      id: json['id'] as String? ?? '',
      alias: json['alias'] as String? ?? '',
      nameKey: json['nameKey'] as String? ?? '',
      sourceKey: json['sourceKey'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'unknown.webp',
      objclass: json['objclass'] as String? ?? '',
      objdata: rawObjdata is Map
          ? Map<String, dynamic>.from(rawObjdata)
          : const <String, dynamic>{},
    );
  }
}
