import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';

class OptionsSchema {
  bool receiveOpen; // FUTURE:GG options unread + notification TODO:GG black?
  bool notificationOpen; // FUTURE:GG options  topic TODO:GG duplicated to field muteExpireAt, maybe can convert to a params notificationOpen(only get)?
  int muteExpireAt; // FUTURE:GG options  chat TODO:GG like deviceToken:expireTimeAt?
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
    this.notificationOpen = false,
    this.muteExpireAt = -1,
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
    if (avatarBgColor == null) avatarBgColor = application.theme.randomBackgroundColorList[random];
    if (avatarNameColor == null) avatarNameColor = application.theme.randomColorList[random];
  }

  Map<String, dynamic> toMap() {
    final random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    Map<String, dynamic> map = {};
    map['receiveOpen'] = receiveOpen ? 1 : 0;
    map['notificationOpen'] = notificationOpen ? 1 : 0;
    map['muteExpireAt'] = muteExpireAt;
    map['soundResource'] = soundResource;
    map['deleteAfterSeconds'] = deleteAfterSeconds;
    map['updateBurnAfterAt'] = updateBurnAfterAt;
    map['avatarBgColor'] = avatarBgColor?.value ?? application.theme.randomBackgroundColorList[random];
    map['avatarNameColor'] = avatarNameColor?.value ?? application.theme.randomColorList[random];
    map['chatBgFile'] = Path.convert2Local(chatBgFile?.path);
    map['chatBgColor'] = chatBgColor?.value;
    map['chatBubbleBgColor'] = chatBubbleBgColor?.value;
    map['chatBubbleTextColor'] = chatBubbleTextColor?.value;
    return map;
  }

  static OptionsSchema fromMap(Map map) {
    OptionsSchema schema = OptionsSchema();
    final random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    schema.receiveOpen = (map['receiveOpen'] != null && map['receiveOpen'].toString() == '1') ? true : false;
    schema.notificationOpen = (map['notificationOpen'] != null && map['notificationOpen'].toString() == '1') ? true : false;
    schema.muteExpireAt = map['muteExpireAt'] ?? -1;
    schema.soundResource = map['soundResource'];
    schema.deleteAfterSeconds = map['deleteAfterSeconds'];
    schema.updateBurnAfterAt = map['updateBurnAfterAt'];
    schema.avatarBgColor = map['avatarBgColor'] != null ? Color(map['avatarBgColor']) : application.theme.randomBackgroundColorList[random];
    schema.avatarNameColor = map['avatarNameColor'] != null ? Color(map['avatarNameColor']) : application.theme.randomColorList[random];
    schema.chatBgFile = Path.convert2Complete(map['chatBgFile']) != null ? File(Path.convert2Complete(map['chatBgFile'])!) : null;
    schema.chatBgColor = map['chatBgColor'] != null ? Color(map['avatarBgColor']) : schema.chatBgColor;
    schema.chatBubbleBgColor = map['chatBubbleBgColor'] != null ? Color(map['chatBubbleBgColor']) : schema.chatBubbleBgColor;
    schema.chatBubbleTextColor = map['chatBubbleTextColor'] != null ? Color(map['chatBubbleTextColor']) : schema.chatBubbleTextColor;
    return schema;
  }

  @override
  String toString() {
    return 'OptionsSchema{receiveOpen: $receiveOpen, notificationOpen: $notificationOpen, muteExpireAt: $muteExpireAt, soundResource: $soundResource, deleteAfterSeconds: $deleteAfterSeconds, updateBurnAfterAt: $updateBurnAfterAt, avatarBgColor: $avatarBgColor, avatarNameColor: $avatarNameColor, chatBgFile: $chatBgFile, chatBgColor: $chatBgColor, chatBubbleBgColor: $chatBubbleBgColor, chatBubbleTextColor: $chatBubbleTextColor}';
  }
}
