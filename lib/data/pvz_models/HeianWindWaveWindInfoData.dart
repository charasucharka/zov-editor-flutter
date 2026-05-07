import 'package:z_editor/data/pvz_models/PvzModel.dart';

import 'package:z_editor/data/pvz_models/HeianWindInfoData.dart';

class HeianWindWaveWindInfoData extends PvzModel {
  HeianWindWaveWindInfoData({
    this.waveNumber = 0,
    this.windDelay = 0,
    List<HeianWindInfoData>? windInfos,
  }) : windInfos = windInfos ?? [];

  /// 0-based wave index.
  int waveNumber;
  int windDelay;
  List<HeianWindInfoData> windInfos;

  factory HeianWindWaveWindInfoData.fromJson(Map<String, dynamic> json) {
    final windList = json['WindInfos'] as List<dynamic>?;
    final gameWave = (json['WaveNumber'] as num?)?.toInt() ?? 1;
    return HeianWindWaveWindInfoData(
      waveNumber: gameWave < 1 ? 0 : gameWave - 1,
      windDelay: (json['WindDelay'] as num?)?.toInt() ?? 0,
      windInfos:
          windList
              ?.map(
                (e) => HeianWindInfoData.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'WaveNumber': waveNumber + 1,
    'WindDelay': windDelay,
    'WindInfos': windInfos.map((e) => e.toJson()).toList(),
  };
}

