import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';

class OptionsSchema {
  bool isBlack;

  bool notificationOpen;
  String? pushToken; // deviceToken or topicName

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
    this.isBlack = false,
    this.notificationOpen = false,
    this.pushToken,
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
    map['isBlack'] = isBlack;
    map['notificationOpen'] = notificationOpen;
    map['pushToken'] = pushToken;
    map['deleteAfterSeconds'] = deleteAfterSeconds;
    map['updateBurnAfterTime'] = updateBurnAfterAt;
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
    schema.isBlack = map['isBlack'] ?? false;
    schema.notificationOpen = map['notificationOpen'] ?? false;
    schema.pushToken = map['pushToken'];
    schema.deleteAfterSeconds = map['deleteAfterSeconds'];
    schema.updateBurnAfterAt = map['updateBurnAfterTime'];
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
    return 'OptionsSchema{isBlack: $isBlack, notificationOpen: $notificationOpen, pushToken: $pushToken, deleteAfterSeconds: $deleteAfterSeconds, updateBurnAfterAt: $updateBurnAfterAt, soundResource: $soundResource, muteExpireAt: $muteExpireAt, avatarBgColor: $avatarBgColor, avatarNameColor: $avatarNameColor, chatBgFile: $chatBgFile, chatBgColor: $chatBgColor, chatBubbleBgColor: $chatBubbleBgColor, chatBubbleTextColor: $chatBubbleTextColor}';
  }
}
