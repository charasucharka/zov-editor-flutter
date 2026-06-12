import 'package:collection/collection.dart';
import 'package:c_editor/data/pvz_models/PvzLevelFile.dart';
import 'package:c_editor/data/rtid_parser.dart';

/// Helpers for [ZombossFinalStageTimeLimitedChallengeProperties] (LevelModules-only).
abstract class FinalStageTimeLimitedModuleUtils {
  FinalStageTimeLimitedModuleUtils._();

  static const alias = 'FinalStageTimeLimitedChallenge';
  static const objClass = 'ZombossFinalStageTimeLimitedChallengeProperties';

  /// Ensures the module references `@LevelModules` only and drops misleading
  /// level-local property objects (the game reads the timer from zomboss props).
  static void normalizeForLevelModulesOnly(PvzLevelFile levelFile) {
    levelFile.objects.removeWhere((o) => o.objClass == objClass);

    final levelDefObj = levelFile.objects
        .where((o) => o.objClass == 'LevelDefinition')
        .firstOrNull;
    if (levelDefObj?.objData is! Map) return;

    final objData = levelDefObj!.objData as Map;
    final modules = objData['Modules'];
    if (modules is! List) return;

    for (var i = 0; i < modules.length; i++) {
      final raw = modules[i];
      if (raw is! String) continue;
      final info = RtidParser.parse(raw);
      if (info?.alias == alias) {
        modules[i] = RtidParser.build(alias, 'LevelModules');
      }
    }
  }
}
