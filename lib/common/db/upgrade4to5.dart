import 'dart:convert';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

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

    // v5 table
    if (!(await DB.checkTableExists(db, ContactStorage.tableName))) {
      await db.execute(ContactStorage.createSQL);
    }

    // v1 table
    String oldTableName = "Contact";
    if ((await DB.checkTableExists(db, oldTableName))) {
      List<Map<String, dynamic>>? results = await db.query(
        oldTableName,
        columns: ['*'],
      );
      // convert all v1Data to v5Data
      if (results != null && results.length > 0) {
        int total = 0;
        for (var i = 0; i < results.length; i++) {
          Map<String, dynamic> result = results[i];

          // address
          String? oldAddress = result["address"];
          if (oldAddress == null || oldAddress.isEmpty) {
            logger.w("Upgrade4to5 - $oldTableName query - address is null - data:$result");
          }
          String? newAddress = ((oldAddress?.isNotEmpty == true) && (oldAddress!.length <= 200)) ? oldAddress : null;
          if (newAddress == null || newAddress.isEmpty) {
            logger.w("Upgrade4to5 - $oldTableName convert - address error - data:$result");
            continue;
          }
          // type
          String? oldType = result["type"];
          if (oldType == null || oldType.isEmpty) {
            logger.w("Upgrade4to5 - $oldTableName query - type is null - data:$result");
          }
          int newType = ContactType.none;
          if (oldType == 'me') {
            newType = ContactType.me;
          } else if (oldType == 'stranger') {
            newType = ContactType.stranger;
          } else if (oldType == 'friend') {
            newType = ContactType.friend;
          }
          // at
          int? oldCreateAt = result["created_time"];
          int? oldUpdateAt = result["updated_time"];
          if (oldCreateAt == null || oldCreateAt == 0 || oldUpdateAt == null || oldUpdateAt == 0) {
            logger.w("Upgrade4to5 - $oldTableName query - at is null - data:$result");
          }
          int newCreateAt = (oldCreateAt == null || oldCreateAt == 0) ? DateTime.now().millisecondsSinceEpoch : oldCreateAt;
          int newUpdateAt = (oldUpdateAt == null || oldUpdateAt == 0) ? DateTime.now().millisecondsSinceEpoch : oldUpdateAt;
          // profile
          String? newAvatar = result["avatar"];
          String? newFirstName = result["first_name"];
          String? newLastName = result["last_name"];
          // profileExtra
          String? newProfileVersion = result["profile_version"] ?? Uuid().v4();
          String? newProfileExpireAt = result["profile_expires_at"] ?? (DateTime.now().millisecondsSinceEpoch - Global.profileExpireMs);
          // top + token
          int newIsTop = result["is_top"] ?? 0;
          String? newDeviceToken = result["device_token"];
          // options
          OptionsSchema oldOptionsSchema = OptionsSchema();
          try {
            Map<String, dynamic>? oldOptionsMap = (result["options"]?.toString().isNotEmpty == true) ? jsonDecode(result['options']) : null;
            if (oldOptionsMap != null && oldOptionsMap.isNotEmpty) {
              oldOptionsSchema.deleteAfterSeconds = oldOptionsMap['deleteAfterSeconds'];
              oldOptionsSchema.updateBurnAfterAt = oldOptionsMap['updateTime'];
              oldOptionsSchema.avatarBgColor = oldOptionsMap['backgroundColor'];
              oldOptionsSchema.avatarNameColor = oldOptionsMap['color'];
            }
          } catch (e) {
            handleError(e);
            logger.w("Upgrade4to5 - $oldTableName query - options(old) error - data:$result");
          }
          oldOptionsSchema.notificationOpen = result["notification_open"] ?? false;
          String? newOptions;
          try {
            newOptions = jsonEncode(oldOptionsSchema.toMap());
          } catch (e) {
            handleError(e);
            logger.w("Upgrade4to5 - $oldTableName query - options(new) error - data:$result");
          }
          // data
          Map<String, dynamic> oldDataMap;
          try {
            oldDataMap = (result['data']?.toString().isNotEmpty == true) ? jsonDecode(result['data']) : Map();
          } catch (e) {
            handleError(e);
            logger.w("Upgrade4to5 - $oldTableName query - data(old) error - data:$result");
            oldDataMap = Map();
          }
          Map<String, dynamic> newDataMap = Map();
          newDataMap['nknWalletAddress'] = oldDataMap['nknWalletAddress']; // too loong to check
          newDataMap['notes'] = oldDataMap['notes'];
          newDataMap['avatar'] = oldDataMap['remark_avatar'];
          newDataMap['firstName'] = oldDataMap['firstName'] ?? oldDataMap['remark_name'] ?? oldDataMap['notes'];

          // insert v5 table
          Map<String, dynamic> entity = {
            "address": newAddress,
            "type": newType,
            "create_at": newCreateAt,
            "update_at": newUpdateAt,
            "avatar": newAvatar,
            "first_name": newFirstName,
            "last_name": newLastName,
            "profile_version": newProfileVersion,
            "profile_expires_at": newProfileExpireAt,
            "is_top": newIsTop,
            "device_token": newDeviceToken,
            "options": newOptions,
            "data": "",
          };
          int count = await db.insert(ContactStorage.tableName, entity);
          if (count > 0) {
            logger.d("Upgrade4to5 - ${ContactStorage.tableName} added success - data:$entity");
          } else {
            logger.w("Upgrade4to5 - ${ContactStorage.tableName} added fail - data:$entity");
          }
          total += count;
        }
        logger.i("Upgrade4to5 - ${ContactStorage.tableName} added - total:$total");
      } else {
        logger.i("Upgrade4to5 - $oldTableName query - empty");
      }
    }
  }

  static Future createDeviceInfo(Database db) async {
    await DeviceInfoStorage.create(db);
  }

  static Future upgradeTopic(Database db) async {
    // TODO:GG db topic
    // await db.execute('ALTER TABLE $subsriberTable ADD COLUMN member_status BOOLEAN DEFAULT 0');
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
