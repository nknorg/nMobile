import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';

class OptionsSchema {
  bool receiveOpen; // FUTURE:GG options unread + notification TODO:GG 拉黑?
  int? muteExpireAt; // FUTURE:GG options  chat TODO:GG 需要把deviceToken传进去的时候，顺便在后面跟上过期时间，不跟随deviceInfo
  bool notificationOpen; // FUTURE:GG options  topic TODO:GG 和muteExpireAt功能重合了，可以根据muteExpireAt来做成get属性
  String? soundResource; // FUTURE:GG options  chat

  // burning
  int? deleteAfterSeconds;
  int? updateBurnAfterAt;
  // contact_style
  Color? avatarBgColor;
  Color? avatarNameColor;
  // chat_style
  File? chatBgFile; // FUTURE:GG options  ui
  Color? chatBgColor; // FUTURE:GG options  ui
  Color? chatBubbleBgColor; // FUTURE:GG options  ui
  Color? chatBubbleTextColor; // FUTURE:GG options  ui

  OptionsSchema({
    this.receiveOpen = false,
    this.muteExpireAt = -1,
    this.notificationOpen = false,
    this.soundResource,
    this.deleteAfterSeconds,
    this.updateBurnAfterAt,
    this.avatarBgColor,
    this.avatarNameColor,
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
    map['muteExpireAt'] = muteExpireAt;
    map['notificationOpen'] = notificationOpen ? 1 : 0;
    map['soundResource'] = soundResource;
    map['deleteAfterSeconds'] = deleteAfterSeconds;
    map['updateBurnAfterAt'] = updateBurnAfterAt;
    map['avatarBgColor'] = avatarBgColor?.value;
    map['avatarNameColor'] = avatarNameColor?.value;
    map['chatBgFile'] = Path.convert2Local(chatBgFile?.path);
    map['chatBgColor'] = chatBgColor?.value;
    map['chatBubbleBgColor'] = chatBubbleBgColor?.value;
    map['chatBubbleTextColor'] = chatBubbleTextColor?.value;
    return map;
  }

  static OptionsSchema fromMap(Map map) {
    OptionsSchema schema = OptionsSchema();
    schema.receiveOpen = (map['receiveOpen'] != null && map['receiveOpen'].toString() == '1') ? true : false;
    schema.muteExpireAt = map['muteExpireAt'];
    schema.notificationOpen = (map['notificationOpen'] != null && map['notificationOpen'].toString() == '1') ? true : false;
    schema.soundResource = map['soundResource'];
    schema.deleteAfterSeconds = map['deleteAfterSeconds'];
    schema.updateBurnAfterAt = map['updateBurnAfterAt'];
    schema.avatarBgColor = map['avatarBgColor'] != null ? Color(map['avatarBgColor']) : schema.avatarBgColor;
    schema.avatarNameColor = map['avatarNameColor'] != null ? Color(map['avatarNameColor']) : schema.avatarNameColor;
    schema.chatBgFile = Path.convert2Complete(map['chatBgFile']) != null ? File(Path.convert2Complete(map['chatBgFile'])!) : null;
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
