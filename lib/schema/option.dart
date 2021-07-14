import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';

class OptionsSchema {
  bool receiveOpen;
  bool notificationOpen;

  int? deleteAfterSeconds;
  int? updateBurnAfterAt;

  String? soundResource;
  int? muteExpireAt;

  Color? avatarBgColor;
  Color? avatarNameColor;

  File? chatBgFile;
  Color? chatBgColor;

  Color? chatBubbleBgColor;
  Color? chatBubbleTextColor;

  OptionsSchema({
    this.receiveOpen = false,
    this.notificationOpen = false,
    this.deleteAfterSeconds,
    this.updateBurnAfterAt,
    this.avatarNameColor,
    this.avatarBgColor,
    this.chatBgFile,
    this.chatBgColor,
    this.chatBubbleBgColor,
    this.chatBubbleTextColor,
  }) {
    final random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    if (avatarBgColor == null) {
      avatarBgColor = application.theme.randomBackgroundColorList[random];
    }
    if (avatarNameColor == null) {
      avatarNameColor = application.theme.randomColorList[random];
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    map['receiveOpen'] = receiveOpen ? 1 : 0;
    map['notificationOpen'] = notificationOpen ? 1 : 0;
    map['deleteAfterSeconds'] = deleteAfterSeconds;
    map['updateBurnAfterAt'] = updateBurnAfterAt;
    map['soundResource'] = soundResource;
    map['muteExpireAt'] = muteExpireAt;
    map['avatarBgColor'] = avatarBgColor?.value;
    map['avatarNameColor'] = avatarNameColor?.value;
    map['chatBgFile'] = Path.getLocalFile(chatBgFile?.path);
    map['chatBgColor'] = chatBgColor?.value;
    map['chatBubbleBgColor'] = chatBubbleBgColor?.value;
    map['chatBubbleTextColor'] = chatBubbleTextColor?.value;
    return map;
  }

  static OptionsSchema fromMap(Map map) {
    OptionsSchema schema = OptionsSchema();
    schema.receiveOpen = (map['receiveOpen'] != null && map['receiveOpen'].toString() == '1') ? true : false;
    schema.notificationOpen = (map['notificationOpen'] != null && map['notificationOpen'].toString() == '1') ? true : false;
    schema.deleteAfterSeconds = map['deleteAfterSeconds'];
    schema.updateBurnAfterAt = map['updateBurnAfterAt'];
    schema.soundResource = map['soundResource'];
    schema.muteExpireAt = map['muteExpireAt'];
    schema.avatarBgColor = map['avatarBgColor'] != null ? Color(map['avatarBgColor']) : schema.avatarBgColor;
    schema.avatarNameColor = map['avatarNameColor'] != null ? Color(map['avatarNameColor']) : schema.avatarNameColor;
    schema.chatBgFile = Path.getCompleteFile(map['chatBgFile']) != null ? File(Path.getCompleteFile(map['chatBgFile'])!) : null;
    schema.chatBgColor = map['chatBgColor'] != null ? Color(map['avatarBgColor']) : schema.chatBgColor;
    schema.chatBubbleBgColor = map['chatBubbleBgColor'] != null ? Color(map['chatBubbleBgColor']) : schema.chatBubbleBgColor;
    schema.chatBubbleTextColor = map['chatBubbleTextColor'] != null ? Color(map['chatBubbleTextColor']) : schema.chatBubbleTextColor;
    return schema;
  }

  @override
  String toString() {
    return 'OptionsSchema{receiveOpen: $receiveOpen, notificationOpen: $notificationOpen, deleteAfterSeconds: $deleteAfterSeconds, updateBurnAfterAt: $updateBurnAfterAt, soundResource: $soundResource, muteExpireAt: $muteExpireAt, avatarBgColor: $avatarBgColor, avatarNameColor: $avatarNameColor, chatBgFile: $chatBgFile, chatBgColor: $chatBgColor, chatBubbleBgColor: $chatBubbleBgColor, chatBubbleTextColor: $chatBubbleTextColor}';
  }
}
