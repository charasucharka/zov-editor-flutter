/// One row in `PvzLevelFile.objects` (`aliases`, `objclass`, `objdata`).
class PvzObject {
  PvzObject({this.aliases, required this.objClass, required this.objData});

  List<String>? aliases;
  final String objClass;
  dynamic objData;

  factory PvzObject.fromJson(Map<String, dynamic> json) {
    final aliases = json['aliases'] as List<dynamic>?;
    return PvzObject(
      aliases: aliases?.cast<String>(),
      objClass: json['objclass'] as String? ?? '',
      objData: json['objdata'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (aliases != null) 'aliases': aliases,
    'objclass': objClass,
    'objdata': objData,
  };
}
