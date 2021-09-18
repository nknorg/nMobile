import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/session.dart';
import 'package:sqflite/sqflite.dart';

class Upgrade4to5 {
  static Future upgradeContact(Database db) async {
    // id (NULL) -> id (NOT NULL)
    // TODO:GG address (TEXT) -> address (VARCHAR(200))
    // TODO:GG type (TEXT) -> type (INT)
    // TODO:GG created_time (INTEGER) -> create_at (BIGINT)
    // TODO:GG updated_time (INTEGER) -> update_at (BIGINT)
    // avatar (TEXT) -> avatar (TEXT)
    // TODO:GG first_name (TEXT) -> first_name (VARCHAR(50))
    // TODO:GG last_name (TEXT) -> last_name (VARCHAR(50))
    // TODO:GG profile_version (TEXT) -> profile_version (VARCHAR(300))
    // TODO:GG profile_expires_at (INTEGER) -> profile_expires_at (BIGINT)
    // is_top (BOOLEAN) -> is_top (BOOLEAN)
    // device_token (TEXT) -> device_token (TEXT)
    // options (TEXT) -> options (TEXT)
    // data (TEXT) -> data( TEXT)
    // TODO:GG notification_open (BOOLEAN) -> options.notificationOpen
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
