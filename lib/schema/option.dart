import 'dart:math';
import 'dart:ui';

import 'package:nmobile/common/locator.dart';

class OptionsSchema {
  int? deleteAfterSeconds;
  int? updateBurnAfterTime;
  Color? backgroundColor;
  Color? color;

  OptionsSchema({
    this.deleteAfterSeconds,
    this.updateBurnAfterTime,
    this.backgroundColor,
    this.color,
  }) {
    final random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    if (backgroundColor == null) {
      backgroundColor = application.theme.randomBackgroundColorList[random];
    }
    if (color == null) {
      color = application.theme.randomColorList[random];
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    map['deleteAfterSeconds'] = deleteAfterSeconds;
    map['updateBurnAfterTime'] = updateBurnAfterTime;
    map['backgroundColor'] = backgroundColor?.value;
    map['color'] = color?.value;
    return map;
  }

  OptionsSchema.fromMap(Map map) {
    this.deleteAfterSeconds = map['deleteAfterSeconds'];
    this.updateBurnAfterTime = map['updateBurnAfterTime'];
    this.backgroundColor = Color(map['backgroundColor']);
    this.color = Color(map['color']);
  }

  @override
  String toString() {
    return 'OptionsSchema{deleteAfterSeconds: $deleteAfterSeconds, updateBurnAfterTime: $updateBurnAfterTime, backgroundColor: $backgroundColor, color: $color}';
  }
}
