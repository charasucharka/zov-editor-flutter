/// Base for JSON-serializable `objdata` payloads (not the level file row wrapper).
abstract class PvzModel {
  Map<String, dynamic> toJson();
}
