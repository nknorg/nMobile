import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/session.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class Upgrade4to5 {
  static Future upgradeContact(Database db) async {
    // TODO:GG db contact
  }

  static Future createDeviceInfo(Database db) async {
    await DeviceInfoStorage.create(db);
  }

  static Future upgradeTopic(Database db) async {
    // TODO:GG db topic
  }

  static Future upgradeSubscriber(Database db) async {
    // TODO:GG db subscriber
  }

  static Future upgradeMessages(Database db) async {
    // TODO:GG db messages
    // TODO:GG delete message(receipt) + read message(piece + contactOptions)
  }

  static Future createSession(Database db) async {
    await SessionStorage.create(db);
    // TODO:GG 取消息的最后一条，聚合成session，还有未读数等其他字段
  }
}
