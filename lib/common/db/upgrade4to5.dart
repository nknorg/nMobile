import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class Upgrade4to5 {
  static Future upgradeContact(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    // id (NULL) -> id (NOT NULL)
    // address (TEXT) -> address (VARCHAR(200))
    // type (TEXT) -> type (INT)
    // created_time (INTEGER) -> create_at (BIGINT)
    // updated_time (INTEGER) -> update_at (BIGINT)
    // avatar (TEXT) -> avatar (TEXT)
    // first_name (TEXT) -> first_name (VARCHAR(50))
    // last_name (TEXT) -> last_name (VARCHAR(50))
    // profile_version (TEXT) -> profile_version (VARCHAR(300))
    // profile_expires_at (INTEGER) -> profile_expires_at (BIGINT)
    // is_top (BOOLEAN) -> is_top (BOOLEAN)
    // device_token (TEXT) -> device_token (TEXT)
    // options (TEXT) -> options (TEXT)
    // data (TEXT) -> data( TEXT)
    // notification_open (BOOLEAN) -> options.notificationOpen

    upgradeTipStream?.add("... (1/7)");

    // v5 table
    if (!(await DB.checkTableExists(db, ContactStorage.tableName))) {
      upgradeTipStream?.add(".... (1/7)");
      await ContactStorage.create(db);
    } else {
      logger.w("Upgrade4to5 - ${ContactStorage.tableName} exist");
    }
    upgradeTipStream?.add("..... (1/7)");

    // v2 table
    String oldTableName = "Contact";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade4to5 - $oldTableName no exist");
      return;
    }
    upgradeTipStream?.add("...... (1/7)");

    // total
    final rawCountMap = await db.query(oldTableName, columns: ['COUNT(id)']);
    int rawCount = Sqflite.firstIntValue(rawCountMap) ?? 0;

    // convert all v2Data to v5Data
    int total = 0;
    int offset = 0;
    int limit = 30;
    bool loop = true;
    while (loop) {
      List<Map<String, dynamic>>? results = await db.query(oldTableName, columns: ['*'], orderBy: 'id ASC', offset: offset, limit: limit);
      if (results == null || results.isEmpty) {
        loop = false;
        logger.i("Upgrade4to5 - $oldTableName loop over");
        break;
      } else {
        offset += limit;
        logger.i("Upgrade4to5 - $oldTableName offset++ - offset:$offset");
      }

      // loop offset:limit
      for (var i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];

        // address
        String? oldAddress = result["address"];
        if (oldAddress == null || oldAddress.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - address is null - data:$result");
        } else if (oldAddress.contains(".__permission__.")) {
          final splits = oldAddress.split(".__permission__.");
          oldAddress = splits.length > 0 ? splits[splits.length - 1] : "";
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
        int newUpdateAt = (oldUpdateAt == null || oldUpdateAt == 0) ? newCreateAt : oldUpdateAt;
        // profileExtra
        String? newProfileVersion = Uuid().v4(); // (result["profile_version"]?.toString().length ?? 0) > 300) ? result["profile_version"]?.toString().substring(0, 300) : result["profile_version"]) ?? Uuid().v4();
        int? newProfileExpireAt = result["profile_expires_at"] ?? (DateTime.now().millisecondsSinceEpoch - Global.profileExpireMs);
        // top + token
        int newIsTop = 0; // (result["is_top"]?.toString() == '1') ? 1 : 0;
        String? newDeviceToken = result["device_token"];
        // options
        OptionsSchema newOptionsSchema = OptionsSchema();
        try {
          Map<String, dynamic>? oldOptionsMap = (result["options"]?.toString().isNotEmpty == true) ? jsonDecode(result['options']) : null;
          if (oldOptionsMap != null && oldOptionsMap.isNotEmpty) {
            newOptionsSchema.deleteAfterSeconds = oldOptionsMap['deleteAfterSeconds'];
            newOptionsSchema.updateBurnAfterAt = oldOptionsMap['updateTime'];
            newOptionsSchema.avatarBgColor = oldOptionsMap['backgroundColor'] != null ? Color(oldOptionsMap['backgroundColor']) : null;
            newOptionsSchema.avatarNameColor = oldOptionsMap['color'] != null ? Color(oldOptionsMap['color']) : null;
          }
        } catch (e) {
          handleError(e);
          logger.w("Upgrade4to5 - $oldTableName query - options(old) error - data:$result");
        }
        newOptionsSchema.notificationOpen = (result["notification_open"]?.toString() == '1') ? true : false;
        String? newOptions;
        try {
          newOptions = jsonEncode(newOptionsSchema.toMap());
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
        newDataMap['firstName'] = oldDataMap['remark_name'];
        newDataMap['avatar'] = oldDataMap['remark_avatar'];
        newDataMap['notes'] = oldDataMap['notes'];
        String? newData;
        try {
          newData = jsonEncode(newDataMap);
        } catch (e) {
          handleError(e);
          logger.w("Upgrade4to5 - $oldTableName query - data(new) error - data:$result");
        }
        // profile
        String? oldAvatar = Path.getLocalFile(oldDataMap['avatar']); // why oldDataMap?
        String? newAvatar = (oldAvatar?.isNotEmpty == true) ? oldAvatar : Path.getLocalFile(result["avatar"]);
        String? oldFirstName = ((oldDataMap["firstName"]?.toString().length ?? 0) > 50) ? oldDataMap["firstName"]?.toString().substring(0, 50) : oldDataMap["firstName"];
        String? newFirstName = (oldFirstName?.isNotEmpty == true) ? oldFirstName : (((result["first_name"]?.toString().length ?? 0) > 50) ? result["first_name"]?.toString().substring(0, 50) : result["first_name"]);
        String? oldLastName = ((oldDataMap["lastName"]?.toString().length ?? 0) > 50) ? oldDataMap["lastName"]?.toString().substring(0, 50) : oldDataMap["lastName"];
        String? newLastName = (oldLastName?.isNotEmpty == true) ? oldLastName : (((result["last_name"]?.toString().length ?? 0) > 50) ? result["last_name"]?.toString().substring(0, 50) : result["last_name"]);

        // duplicated
        List<Map<String, dynamic>>? duplicated = await db.query(ContactStorage.tableName, columns: ['*'], where: 'address = ?', whereArgs: [newAddress], offset: 0, limit: 1);
        if (duplicated != null && duplicated.length > 0) {
          logger.w("Upgrade4to5 - ${ContactStorage.tableName} query - duplicated - data:$result - duplicated:$duplicated");
          continue;
        }

        // insert v5Data
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
          "data": newData,
        };
        int id = await db.insert(ContactStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade4to5 - ${ContactStorage.tableName} added success - data:$entity");
          total += 1;
        } else {
          logger.w("Upgrade4to5 - ${ContactStorage.tableName} added fail - data:$entity");
        }
        upgradeTipStream?.add("${(total * 100) ~/ (rawCount * 100)}% (1/7)");
      }
    }
    if (total != rawCount) {
      logger.w("Upgrade4to5 - ${ContactStorage.tableName} added end - rawCount:$rawCount - total:$total");
    } else {
      logger.i("Upgrade4to5 - ${ContactStorage.tableName} added end - total:$total");
    }
  }

  static Future createDeviceInfo(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    upgradeTipStream?.add("... (2/7)");
    // just create table
    if (!(await DB.checkTableExists(db, DeviceInfoStorage.tableName))) {
      await DeviceInfoStorage.create(db);
    } else {
      logger.w("Upgrade4to5 - ${DeviceInfoStorage.tableName} exist");
    }
  }

  static Future upgradeTopic(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    // id (NULL) -> id (NOT NULL)
    // topic (TEXT) -> topic (VARCHAR(200))
    // ??/type (INTEGER) -> type (INT)
    // ?? -> create_at (BIGINT)
    // ?? -> update_at (BIGINT)
    // ??/joined (BOOLEAN) -> joined (BOOLEAN)
    // ??/time_update (INTEGER) -> subscribe_at (BIGINT)
    // expire_at (INTEGER) -> expire_height (BIGINT)
    // avatar (TEXT) -> avatar (TEXT)
    // count (INTEGER) -> count (INT)
    // is_top (BOOLEAN) -> is_top (BOOLEAN)
    // options (TEXT) -> options (TEXT)
    // ?? -> data (TEXT)
    // accept_all (BOOLEAN) -> ??
    // theme_id (INTEGER) -> ??

    upgradeTipStream?.add("... (3/7)");

    // v5 table
    if (!(await DB.checkTableExists(db, TopicStorage.tableName))) {
      upgradeTipStream?.add(".... (3/7)");
      await TopicStorage.create(db);
    } else {
      logger.w("Upgrade4to5 - ${TopicStorage.tableName} exist");
    }
    upgradeTipStream?.add("..... (3/7)");

    // v2 table
    String oldTableName = 'topic';
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.i("Upgrade4to5 - $oldTableName no exist");
      return;
    }
    upgradeTipStream?.add("...... (3/7)");

    // total
    final rawCountMap = await db.query(oldTableName, columns: ['COUNT(id)']);
    int rawCount = Sqflite.firstIntValue(rawCountMap) ?? 0;

    // convert all v2Data to v5Data
    int total = 0;
    int offset = 0;
    int limit = 30;
    bool loop = true;
    while (loop) {
      List<Map<String, dynamic>>? results = await db.query(oldTableName, columns: ['*'], orderBy: 'id ASC', offset: offset, limit: limit);
      if (results == null || results.isEmpty) {
        loop = false;
        logger.i("Upgrade4to5 - $oldTableName loop over");
        break;
      } else {
        offset += limit;
        logger.i("Upgrade4to5 - $oldTableName offset++ - offset:$offset");
      }

      // loop offset:limit
      for (var i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];

        // address
        String? oldTopic = result["topic"];
        if (oldTopic == null || oldTopic.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - topic is null - data:$result");
        }
        String? newTopic = ((oldTopic?.isNotEmpty == true) && (oldTopic!.length <= 200)) ? oldTopic : null;
        if (newTopic == null || newTopic.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - topic error - data:$result");
          continue;
        }
        // type
        int? oldType = result["type"];
        if (oldType == null) {
          logger.w("Upgrade4to5 - $oldTableName query - type is null - data:$result");
        }
        int newType;
        if (oldType != null && (oldType == TopicType.privateTopic || oldType == TopicType.privateTopic)) {
          newType = oldType;
        } else {
          newType = Validate.isPrivateTopicOk(newTopic) ? TopicType.privateTopic : TopicType.publicTopic;
        }
        // at
        int? oldCreateAt = result["time_update"];
        int? oldUpdateAt = result["time_update"];
        if (oldCreateAt == null || oldCreateAt == 0 || oldUpdateAt == null || oldUpdateAt == 0) {
          logger.w("Upgrade4to5 - $oldTableName query - at is null - data:$result");
        }
        int newCreateAt = (oldCreateAt == null || oldCreateAt == 0) ? (DateTime.now().millisecondsSinceEpoch - Global.txPoolDelayMs) : oldCreateAt;
        int newUpdateAt = (oldUpdateAt == null || oldUpdateAt == 0) ? newCreateAt : oldUpdateAt;
        // subscribe_at + expire_height
        int? newSubscribeAt = result["time_update"];
        int? newExpireHeight = result["expire_at"];
        // joined
        int newJoined = (newExpireHeight ?? 0) > 0 ? 1 : 0; // result["joined"] ?? 1; // result["joined"] always is 0
        // profile
        String? newAvatar = Path.getLocalFile(result["avatar"]);
        // count + top
        int? newCount = result["count"];
        int newIsTop = 0; // (result["is_top"]?.toString() == '1') ? 1 : 0;
        // options
        OptionsSchema newOptionsSchema = OptionsSchema();
        try {
          Map<String, dynamic>? oldOptionsMap = (result["options"]?.toString().isNotEmpty == true) ? jsonDecode(result['options']) : null;
          if (oldOptionsMap != null && oldOptionsMap.isNotEmpty) {
            newOptionsSchema.deleteAfterSeconds = oldOptionsMap['deleteAfterSeconds'];
            newOptionsSchema.updateBurnAfterAt = oldOptionsMap['updateTime'];
            newOptionsSchema.avatarBgColor = oldOptionsMap['backgroundColor'] != null ? Color(oldOptionsMap['backgroundColor']) : null;
            newOptionsSchema.avatarNameColor = oldOptionsMap['color'] != null ? Color(oldOptionsMap['color']) : null;
          }
        } catch (e) {
          handleError(e);
          logger.w("Upgrade4to5 - $oldTableName query - options(old) error - data:$result");
        }
        String? newOptions;
        try {
          newOptions = jsonEncode(newOptionsSchema.toMap());
        } catch (e) {
          handleError(e);
          logger.w("Upgrade4to5 - $oldTableName query - options(new) error - data:$result");
        }

        // duplicated
        List<Map<String, dynamic>>? duplicated = await db.query(TopicStorage.tableName, columns: ['*'], where: 'topic = ?', whereArgs: [newTopic], offset: 0, limit: 1);
        if (duplicated != null && duplicated.length > 0) {
          logger.w("Upgrade4to5 - ${TopicStorage.tableName} query - duplicated - data:$result - duplicated:$duplicated");
          continue;
        }

        // insert v5Data
        Map<String, dynamic> entity = {
          'topic': newTopic,
          'type': newType,
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'joined': newJoined,
          'subscribe_at': newSubscribeAt,
          'expire_height': newExpireHeight,
          'avatar': newAvatar,
          'count': newCount,
          'is_top': newIsTop,
          'options': newOptions,
          'data': null,
        };
        int id = await db.insert(TopicStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade4to5 - ${TopicStorage.tableName} added success - data:$entity");
          total += 1;
        } else {
          logger.w("Upgrade4to5 - ${TopicStorage.tableName} added fail - data:$entity");
        }
        upgradeTipStream?.add("${(total * 100) ~/ (rawCount * 100)}% (3/7)");
      }
    }
    if (total != rawCount) {
      logger.w("Upgrade4to5 - ${TopicStorage.tableName} added end - rawCount:$rawCount - total:$total");
    } else {
      logger.i("Upgrade4to5 - ${TopicStorage.tableName} added end - total:$total");
    }
  }

  static Future upgradeSubscriber(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    // id (NULL) -> id (NOT NULL)
    // topic (TEXT) -> topic (VARCHAR(200))
    // chat_id (TEXT) -> chat_id (VARCHAR(200))
    // time_create (INTEGER) -> create_at (BIGINT)
    // ??? -> update_at (BIGINT)
    // member_status (BOOLEAN) -> status (INT)
    // prm_p_i (INTEGER) -> perm_page (INT)
    // ??? -> data (TEXT)
    // uploaded (BOOLEAN) -> ???
    // subscribed (BOOLEAN) -> ???
    // upload_done (BOOLEAN) -> ???
    // expire_at (INTEGER) -> ???

    upgradeTipStream?.add("... (4/7)");

    // v5 table
    if (!(await DB.checkTableExists(db, SubscriberStorage.tableName))) {
      upgradeTipStream?.add(".... (4/7)");
      await SubscriberStorage.create(db);
    } else {
      logger.w("Upgrade4to5 - ${SubscriberStorage.tableName} exist");
    }
    upgradeTipStream?.add("..... (4/7)");

    // v4 table
    String oldTableName = "subscriber";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade4to5 - $oldTableName no exist");
      return;
    }
    upgradeTipStream?.add("...... (4/7)");

    // total
    final rawCountMap = await db.query(oldTableName, columns: ['COUNT(id)']);
    int rawCount = Sqflite.firstIntValue(rawCountMap) ?? 0;

    // convert all v4Data to v5Data
    int total = 0;
    int offset = 0;
    int limit = 30;
    bool loop = true;
    while (loop) {
      List<Map<String, dynamic>>? results = await db.query(oldTableName, columns: ['*'], orderBy: 'id ASC', offset: offset, limit: limit);
      if (results == null || results.isEmpty) {
        loop = false;
        logger.i("Upgrade4to5 - $oldTableName loop over");
        break;
      } else {
        offset += limit;
        logger.i("Upgrade4to5 - $oldTableName offset++ - offset:$offset");
      }

      // loop offset:limit
      for (var i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];

        // topic
        String? oldTopic = result["topic"];
        if (oldTopic == null || oldTopic.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - topic is null - data:$result");
        }
        String? newTopic = ((oldTopic?.isNotEmpty == true) && (oldTopic!.length <= 200)) ? oldTopic : null;
        if (newTopic == null || newTopic.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - chat_id error - data:$result");
          continue;
        }
        // chatId
        String? oldChatId = result["chat_id"];
        if (oldChatId == null || oldChatId.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - chat_id is null - data:$result");
        } else if (oldChatId.contains(".__permission__.")) {
          final splits = oldChatId.split(".__permission__.");
          oldChatId = splits.length > 0 ? splits[splits.length - 1] : "";
        }
        String? newChatId = ((oldChatId?.isNotEmpty == true) && (oldChatId!.length <= 200)) ? oldChatId : null;
        if (newChatId == null || newChatId.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - chat_id error - data:$result");
          continue;
        }
        // at
        int? oldCreateAt = result["time_create"];
        if (oldCreateAt == null || oldCreateAt == 0) {
          logger.w("Upgrade4to5 - $oldTableName query - at is null - data:$result");
        }
        int newCreateAt = (oldCreateAt == null || oldCreateAt == 0) ? (DateTime.now().millisecondsSinceEpoch - Global.txPoolDelayMs) : oldCreateAt;
        int newUpdateAt = newCreateAt;
        // type
        int? oldStatus = result["member_status"];
        if (oldStatus == null) {
          logger.w("Upgrade4to5 - $oldTableName query - status is null - data:$result");
        }
        int newStatus = SubscriberStatus.None;
        if (oldStatus == 0 || oldStatus == 1 || oldStatus == 2 || oldStatus == 3) {
          newStatus = oldStatus!;
        } else if (oldStatus == 4 || oldStatus == 5) {
          newStatus = SubscriberStatus.Unsubscribed;
        }
        // permPage
        int? newPermPage = result["prm_p_i"]; // maybe null
        if (newPermPage == null || newPermPage < 0) {
          logger.i("Upgrade4to5 - $oldTableName query - permPage is null - data:$result");
        }

        // duplicated
        List<Map<String, dynamic>>? duplicated = await db.query(SubscriberStorage.tableName, columns: ['*'], where: 'topic = ? AND chat_id = ?', whereArgs: [newTopic, newChatId], offset: 0, limit: 1);
        if (duplicated != null && duplicated.length > 0) {
          logger.w("Upgrade4to5 - ${SubscriberStorage.tableName} query - duplicated - data:$result - duplicated:$duplicated");
          continue;
        }

        // insert v5Data
        Map<String, dynamic> entity = {
          'topic': newTopic,
          'chat_id': newChatId,
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'status': newStatus,
          'perm_page': newPermPage,
          'data': null,
        };
        int id = await db.insert(SubscriberStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade4to5 - ${SubscriberStorage.tableName} added success - data:$entity");
          total += 1;
        } else {
          logger.w("Upgrade4to5 - ${SubscriberStorage.tableName} added fail - data:$entity");
        }
        upgradeTipStream?.add("${(total * 100) ~/ (rawCount * 100)}% (4/7)");
      }
    }
    if (total != rawCount) {
      logger.w("Upgrade4to5 - ${SubscriberStorage.tableName} added end - rawCount:$rawCount - total:$total");
    } else {
      logger.i("Upgrade4to5 - ${SubscriberStorage.tableName} added end - total:$total");
    }
  }

  static Future upgradeMessages(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    // id (NULL) -> id (NOT NULL)
    // pid (TEXT) -> pid (VARCHAR(300))
    // msg_id (TEXT) -> msg_id (VARCHAR(300))
    // sender (TEXT) -> sender (VARCHAR(200))
    // receiver (TEXT) -> receiver (VARCHAR(200))
    // topic (TEXT) -> topic (VARCHAR(200))
    // target_id (TEXT) -> target_id (VARCHAR(200))
    // is_send_error/is_success/is_read (BOOLEAN) -> status (INT)
    // is_outbound (BOOLEAN) -> is_outbound (BOOLEAN)
    // content (TEXT) -> is_delete (BOOLEAN)
    // send_time (INTEGER) -> send_at (BIGINT)
    // receive_time (INTEGER) -> receive_at (BIGINT)
    // delete_time (INTEGER) -> delete_at (BIGINT)
    // type (TEXT) -> type (VARCHAR(30))
    // content (TEXT) -> content (TEXT)
    // options (TEXT) -> options (TEXT)

    upgradeTipStream?.add("... (5/7)");

    // v5 table
    if (!(await DB.checkTableExists(db, MessageStorage.tableName))) {
      upgradeTipStream?.add(".... (5/7)");
      await MessageStorage.create(db);
    } else {
      logger.w("Upgrade4to5 - ${MessageStorage.tableName} exist");
    }
    upgradeTipStream?.add("..... (5/7)");

    // v2 table
    String oldTableName = "Messages";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade4to5 - $oldTableName no exist");
      return;
    }
    upgradeTipStream?.add("...... (5/7)");

    // total
    final rawCountMap = await db.query(oldTableName, columns: ['COUNT(id)']);
    int rawCount = Sqflite.firstIntValue(rawCountMap) ?? 0;

    // convert all v2Data to v5Data
    int total = 0;
    int offset = 0;
    int limit = 30;
    bool loop = true;
    while (loop) {
      List<Map<String, dynamic>>? results = await db.query(oldTableName, columns: ['*'], orderBy: 'id ASC', offset: offset, limit: limit);
      if (results == null || results.isEmpty) {
        loop = false;
        logger.i("Upgrade4to5 - $oldTableName loop over");
        break;
      } else {
        offset += limit;
        logger.i("Upgrade4to5 - $oldTableName offset++ - offset:$offset");
      }

      // loop offset:limit
      for (var i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];

        // delete
        int newIsDelete = 0;
        // type
        String? oldType = result["type"];
        String? newType;
        bool canBurning = false;
        if (oldType == null || oldType.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - type is null - data:$result");
          // continue; // old burning delete
          newIsDelete = 1;
        } else if (oldType == MessageContentType.receipt) {
          logger.w("Upgrade4to5 - $oldTableName convert - type is receipt, need skip - data:$result");
          continue;
        } else if (oldType == MessageContentType.contact) {
          logger.w("Upgrade4to5 - $oldTableName convert - type is contact, need skip - data:$result");
          continue;
        } else if (oldType == MessageContentType.contactOptions) {
          newType = oldType;
        } else if (oldType == MessageContentType.text || oldType == MessageContentType.textExtension) {
          newType = oldType;
          canBurning = true;
        } else if (oldType == MessageContentType.media || oldType == MessageContentType.image || oldType == MessageContentType.audio) {
          newType = oldType;
          canBurning = true;
        } else if (oldType == MessageContentType.piece) {
          logger.w("Upgrade4to5 - $oldTableName convert - type is piece, need skip - data:$result");
          continue;
        } else if (oldType == MessageContentType.topicInvitation || oldType == MessageContentType.topicSubscribe) {
          newType = oldType;
        } else if (oldType == MessageContentType.topicUnsubscribe) {
          logger.w("Upgrade4to5 - $oldTableName convert - type is unsubscribe, need skip - data:$result");
          continue;
        } else {
          logger.w("Upgrade4to5 - $oldTableName convert - type is new ??? - data:$result");
          continue;
        }
        // content
        String? newContent = result['content'];
        if ((newContent == null) || newContent.isEmpty) {
          if (canBurning) {
            logger.i("Upgrade4to5 - $oldTableName convert - content be delete - data:$result");
            // continue; // old burning delete
            newIsDelete = 1;
          }
        }
        // pid
        String? oldPid = result["pid"];
        if (oldPid == null || oldPid.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - pid is null - data:$result");
        }
        String? newPid = (oldPid?.isNotEmpty == true) ? ((oldPid!.length <= 300) ? oldPid : Uuid().v4()) : null;
        if (newPid == null || newPid.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - pid error - data:$result");
        }
        // msgId
        String? oldMsgId = result["msg_id"];
        if (oldMsgId == null || oldMsgId.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - msgId is null - data:$result");
        }
        String? newMsgId = (oldMsgId?.isNotEmpty == true) ? ((oldMsgId!.length <= 300) ? oldMsgId : Uuid().v4()) : null;
        if (newMsgId == null || newMsgId.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - msgId error - data:$result");
          continue; // old burning no delete
        }
        // isOutBound
        int? newIsOutbound = result["is_outbound"];
        if (newIsOutbound == null) {
          if (newIsDelete != 1) {
            logger.w("Upgrade4to5 - $oldTableName convert - isOutBound error - data:$result");
            continue;
          } else {
            logger.i("Upgrade4to5 - $oldTableName convert - isOutBound deleted - data:$result");
          }
        }
        // sender
        String? oldSender = result["sender"];
        if (oldSender == null || oldSender.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - sender is null - data:$result");
        } else if (oldSender.contains(".__permission__.")) {
          final splits = oldSender.split(".__permission__.");
          oldSender = splits.length > 0 ? splits[splits.length - 1] : "";
        }
        String? newSender = ((oldSender?.isNotEmpty == true) && (oldSender!.length <= 200)) ? oldSender : null;
        if (newSender == null || newSender.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - sender error - data:$result");
        }
        // receiver
        String? oldReceiver = result["receiver"];
        if (oldReceiver == null || oldReceiver.isEmpty) {
          logger.i("Upgrade4to5 - $oldTableName query - receiver is null - data:$result");
        } else if (oldReceiver.contains(".__permission__.")) {
          final splits = oldReceiver.split(".__permission__.");
          oldReceiver = splits.length > 0 ? splits[splits.length - 1] : "";
        }
        String? newReceiver = ((oldReceiver?.isNotEmpty == true) && (oldReceiver!.length <= 200)) ? oldReceiver : null;
        if ((oldReceiver?.isNotEmpty == true) && (newReceiver == null || newReceiver.isEmpty)) {
          logger.w("Upgrade4to5 - $oldTableName convert - receiver error - data:$result");
        }
        // topic
        String? oldTopic = result["topic"];
        String? newTopic = ((oldTopic?.isNotEmpty == true) && (oldTopic!.length <= 200)) ? oldTopic : null;
        if ((oldTopic?.isNotEmpty == true) && (newTopic == null || newTopic.isEmpty)) {
          logger.w("Upgrade4to5 - $oldTableName convert - topic error - data:$result");
        }
        // targetId
        String? oldTargetId = result["target_id"];
        if (oldTargetId == null || oldTargetId.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName query - targetId is null - data:$result");
        }
        String? newTargetId = ((oldTargetId?.isNotEmpty == true) && (oldTargetId!.length <= 200)) ? oldTargetId : null;
        if (newTargetId == null || newTargetId.isEmpty) {
          logger.w("Upgrade4to5 - $oldTableName convert - targetId error - data:$result");
          if (newTopic?.isNotEmpty == true) {
            logger.i("Upgrade4to5 - $oldTableName convert - targetId is topic - data:$result");
            newTargetId = newTopic;
          } else if (newIsOutbound == 1) {
            logger.i("Upgrade4to5 - $oldTableName convert - targetId is receiver - data:$result");
            newTargetId = newReceiver;
          } else {
            logger.i("Upgrade4to5 - $oldTableName convert - targetId is sender - data:$result");
            newTargetId = newSender;
          }
        }
        if (newTargetId == null || newTargetId.isEmpty) {
          if (newIsDelete != 1) {
            logger.w("Upgrade4to5 - $oldTableName convert - targetId error - data:$result");
            continue;
          } else {
            logger.i("Upgrade4to5 - $oldTableName convert - targetId deleted - data:$result");
          }
        }
        // status
        int? oldIsSendError = result["is_send_error"];
        // int? oldIsSuccess = result["is_success"];
        int? oldIsRead = result["is_read"];
        int newStatus = MessageStatus.Read;
        if (newIsOutbound == 1) {
          if (oldIsSendError == 1) {
            newStatus = MessageStatus.SendFail;
          }
        } else if (newIsOutbound == 0) {
          if (oldIsRead == null || oldIsRead == 0) {
            newStatus = MessageStatus.Received;
          }
        }
        // at
        int? oldSendAt = result["send_time"];
        int? oldReceiveAt = result["receive_time"];
        int? oldDeleteAt = result["delete_time"];
        if (oldSendAt == null || oldSendAt == 0 || oldReceiveAt == null || oldReceiveAt == 0) {
          logger.w("Upgrade4to5 - $oldTableName query - at is null - data:$result");
        }
        int newCreateAt = (oldSendAt == null || oldSendAt == 0) ? DateTime.now().millisecondsSinceEpoch : oldSendAt;
        int newReceiveAt = (oldReceiveAt == null || oldReceiveAt == 0) ? newCreateAt : oldReceiveAt;
        int? newDeleteAt = canBurning ? ((oldDeleteAt == null || oldDeleteAt == 0) ? null : oldDeleteAt) : null;
        // if (newDeleteAt != null && newDeleteAt < DateTime.now().millisecondsSinceEpoch) {
        //   logger.i("Upgrade4to5 - $oldTableName query - delete time over - data:$result");
        //   newIsDelete = 1;
        // }

        // options
        Map<String, dynamic> oldOptionsMap;
        try {
          oldOptionsMap = (result['options']?.toString().isNotEmpty == true) ? jsonDecode(result['options']) : Map();
        } catch (e) {
          handleError(e);
          logger.w("Upgrade4to5 - $oldTableName query - options(old) error - data:$result");
          oldOptionsMap = Map();
        }
        Map<String, dynamic> newOptionsMap = Map();
        newOptionsMap['audioDuration'] = oldOptionsMap['audioDuration'];
        newOptionsMap['deleteAfterSeconds'] = oldOptionsMap['deleteAfterSeconds'];
        newOptionsMap['updateBurnAfterAt'] = oldOptionsMap['updateTime'] ?? oldOptionsMap['updateBurnAfterTime'] ?? oldOptionsMap['updateBurnAfterAt'];
        // newOptionsMap['deviceToken'] = ???;
        // newOptionsMap['get_at'] = ???;
        // newOptionsMap['from_piece'] = ???;
        // newOptionsMap['piece'] = oldOptionsMap['piece'];
        // newOptionsMap['parentType'] = oldOptionsMap['parentType'];
        // newOptionsMap['bytesLength'] = oldOptionsMap['bytesLength'];
        // newOptionsMap['parity'] = oldOptionsMap['parity'];
        // newOptionsMap['total'] = oldOptionsMap['total'];
        // newOptionsMap['index'] = oldOptionsMap['index'];

        String? newOptions;
        try {
          newOptions = jsonEncode(newOptionsMap);
        } catch (e) {
          handleError(e);
          logger.w("Upgrade4to5 - $oldTableName query - options(new) error - data:$result");
        }

        // duplicated
        List<Map<String, dynamic>>? duplicated = await db.query(MessageStorage.tableName, columns: ['*'], where: 'msg_id = ?', whereArgs: [newMsgId], offset: 0, limit: 1);
        if (duplicated != null && duplicated.length > 0) {
          logger.w("Upgrade4to5 - ${MessageStorage.tableName} query - duplicated - data:$result - duplicated:$duplicated");
          // TODO:GG
          continue;
        }

        // insert v5Data
        Map<String, dynamic> entity = {
          'pid': newPid,
          'msg_id': newMsgId,
          'sender': newSender ?? "",
          'receiver': newReceiver ?? "",
          'topic': newTopic ?? "",
          'target_id': newTargetId ?? "",
          // status
          'status': newStatus,
          'is_outbound': newIsOutbound,
          'is_delete': newIsDelete,
          // at
          'send_at': newCreateAt,
          'receive_at': newReceiveAt,
          'delete_at': newDeleteAt,
          // data
          'type': newType ?? "",
          'content': newContent,
          'options': newOptions,
        };
        int id = await db.insert(MessageStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade4to5 - ${MessageStorage.tableName} added success - data:$entity");
          total += 1;
        } else {
          logger.w("Upgrade4to5 - ${MessageStorage.tableName} added fail - data:$entity");
        }
        upgradeTipStream?.add("${(total * 100) ~/ (rawCount * 100)}% (5/7)");
      }
    }
    if (total != rawCount) {
      logger.w("Upgrade4to5 - ${MessageStorage.tableName} added end - rawCount:$rawCount - total:$total");
    } else {
      logger.i("Upgrade4to5 - ${MessageStorage.tableName} added end - total:$total");
    }
  }

  static Future createSession(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    upgradeTipStream?.add("... (6/7)");

    // create table
    if (!(await DB.checkTableExists(db, SessionStorage.tableName))) {
      await SessionStorage.create(db);
    } else {
      logger.w("Upgrade4to5 - ${SessionStorage.tableName} exist");
    }
    upgradeTipStream?.add(".... (6/7)");

    // total
    final rawCountMap1 = await db.query(ContactStorage.tableName, columns: ['COUNT(id)']);
    int rawCount1 = Sqflite.firstIntValue(rawCountMap1) ?? 0;
    final rawCountMap2 = await db.query(TopicStorage.tableName, columns: ['COUNT(id)']);
    int rawCount2 = Sqflite.firstIntValue(rawCountMap2) ?? 0;
    int rawCount = rawCount1 + rawCount2;

    // contact
    int contactTotal = 0;
    int contactOffset = 0;
    int contactLimit = 30;
    bool contactLoop = true;
    while (contactLoop) {
      List<Map<String, dynamic>>? contacts = await db.query(ContactStorage.tableName, columns: ['*'], offset: contactOffset, limit: contactLimit);
      if (contacts == null || contacts.isEmpty) {
        contactLoop = false;
        break;
      } else {
        contactOffset += contactLimit;
        logger.i("Upgrade4to5 - ${SessionStorage.tableName} next page by contact - offset:$contactOffset");
      }

      // loop offset:limit
      for (var i = 0; i < contacts.length; i++) {
        Map<String, dynamic> contact = contacts[i];

        // me
        if ((contact["type"]?.toString() == ContactType.me.toString()) || (contact["type"]?.toString() == 'me')) {
          logger.i("Upgrade4to5 - ${SessionStorage.tableName} added skip with contact me - contact:$contact");
          continue;
        }

        // targetId
        String? targetId = contact["address"];
        if ((targetId == null) || targetId.isEmpty) {
          logger.w("Upgrade4to5 - ${SessionStorage.tableName} added error with contact address - contact:$contact");
          continue;
        }

        // lastMsg
        List<Map<String, dynamic>>? msgList = await db.query(MessageStorage.tableName, columns: ['*'], where: 'target_id = ?', whereArgs: [targetId], orderBy: "send_at DESC", offset: 0, limit: 1);
        if (msgList == null || msgList.isEmpty) {
          logger.i("Upgrade4to5 - ${SessionStorage.tableName} added reject with no contact message - contact:$contact");
          continue;
        }
        Map<String, dynamic> lastMsgMap = msgList[0];

        // unreadCount
        final res = await db.query(MessageStorage.tableName, columns: ['COUNT(id)'], where: 'status = ? AND is_delete = ? AND target_id = ?', whereArgs: [MessageStatus.Received, 0, targetId]);
        int unreadCount = Sqflite.firstIntValue(res) ?? 0;

        // duplicated
        List<Map<String, dynamic>>? duplicated = await db.query(SessionStorage.tableName, columns: ['*'], where: 'target_id = ? AND type = ?', whereArgs: [targetId, SessionType.CONTACT], offset: 0, limit: 1);
        if (duplicated != null && duplicated.length > 0) {
          logger.w("Upgrade4to5 - ${SessionStorage.tableName} query - duplicated - lastMsg:$lastMsgMap - duplicated:$duplicated");
          continue;
        }

        // insert
        Map<String, dynamic> entity = {
          'target_id': targetId,
          'type': SessionType.CONTACT,
          'last_message_at': lastMsgMap['send_at'],
          'last_message_options': (lastMsgMap.isNotEmpty == true) ? jsonEncode(lastMsgMap) : null,
          'is_top': (contact["is_top"]?.toString() == '1') ? 1 : 0,
          'un_read_count': (unreadCount < 0) ? 0 : unreadCount,
        };
        int id = await db.insert(SessionStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade4to5 - ${SessionStorage.tableName} added by contact success - data:$entity");
          contactTotal += 1;
        } else {
          logger.w("Upgrade4to5 - ${SessionStorage.tableName} added by contact fail - data:$entity");
        }
        upgradeTipStream?.add("${(contactTotal * 100) ~/ (rawCount * 100)}% (6/7)");
      }
    }
    logger.i("Upgrade4to5 - ${SessionStorage.tableName} added end by contact - rawCount:$rawCount1 - total:$contactTotal");

    // topic
    int topicTotal = 0;
    int topicOffset = 0;
    int topicLimit = 30;
    bool topicLoop = true;
    while (topicLoop) {
      List<Map<String, dynamic>>? topics = await db.query(TopicStorage.tableName, columns: ['*'], offset: topicOffset, limit: topicLimit);
      if (topics == null || topics.isEmpty) {
        topicLoop = false;
        break;
      } else {
        topicOffset += topicLimit;
        logger.i("Upgrade4to5 - ${SessionStorage.tableName} next page by topic - offset:$topicOffset");
      }

      // loop offset:limit
      for (var i = 0; i < topics.length; i++) {
        Map<String, dynamic> topic = topics[i];

        // targetId
        String? targetId = topic["topic"];
        if ((targetId == null) || targetId.isEmpty) {
          logger.w("Upgrade4to5 - ${SessionStorage.tableName} added error with topic address - topic:$topic");
          continue;
        }

        // lastMsg
        List<Map<String, dynamic>>? msgList = await db.query(MessageStorage.tableName, columns: ['*'], where: 'target_id = ?', whereArgs: [targetId], orderBy: "send_at DESC", offset: 0, limit: 1);
        if (msgList == null || msgList.isEmpty) {
          logger.i("Upgrade4to5 - ${SessionStorage.tableName} added reject with no topic message - topic:$topic");
          continue;
        }
        Map<String, dynamic> lastMsgMap = msgList[0];

        // unreadCount
        final res = await db.query(MessageStorage.tableName, columns: ['COUNT(id)'], where: 'status = ? AND is_delete = ? AND target_id = ?', whereArgs: [MessageStatus.Received, 0, targetId]);
        int unreadCount = Sqflite.firstIntValue(res) ?? 0;

        // duplicated
        List<Map<String, dynamic>>? duplicated = await db.query(SessionStorage.tableName, columns: ['*'], where: 'target_id = ? AND type = ?', whereArgs: [targetId, SessionType.TOPIC], offset: 0, limit: 1);
        if (duplicated != null && duplicated.length > 0) {
          logger.w("Upgrade4to5 - ${SessionStorage.tableName} query - duplicated - lastMsg:$lastMsgMap - duplicated:$duplicated");
          continue;
        }

        // insert
        Map<String, dynamic> entity = {
          'target_id': targetId,
          'type': SessionType.TOPIC,
          'last_message_at': lastMsgMap['send_at'],
          'last_message_options': (lastMsgMap.isNotEmpty == true) ? jsonEncode(lastMsgMap) : null,
          'is_top': (topic["is_top"]?.toString() == '1') ? 1 : 0,
          'un_read_count': (unreadCount < 0) ? 0 : unreadCount,
        };
        int id = await db.insert(SessionStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade4to5 - ${SessionStorage.tableName} added by topic success - data:$entity");
          topicTotal += 1;
        } else {
          logger.w("Upgrade4to5 - ${SessionStorage.tableName} added by topic fail - data:$entity");
        }
        upgradeTipStream?.add("${((topicTotal + rawCount1) * 100) ~/ (rawCount * 100)}% (6/7)");
      }
    }
    logger.i("Upgrade4to5 - ${SessionStorage.tableName} added end by topic - rawCount:$rawCount2 - total:$topicTotal");
  }

  static Future deletesOldTables(Database db, {StreamSink<String?>? upgradeTipStream}) async {
    // contact
    upgradeTipStream?.add(". (7/7)");
    String oldContactTableName = "Contact";
    if (await DB.checkTableExists(db, oldContactTableName)) {
      int count = await db.delete(oldContactTableName);
      if (count <= 0) {
        logger.w("Upgrade4to5 - $oldContactTableName delete - fail");
      } else {
        logger.i("Upgrade4to5 - $oldContactTableName delete - success");
      }
    } else {
      logger.w("Upgrade4to5 - delete $oldContactTableName no exist");
    }
    // topic
    upgradeTipStream?.add(".. (7/7)");
    String oldTopicTableName = 'topic';
    if (await DB.checkTableExists(db, oldTopicTableName)) {
      int count = await db.delete(oldTopicTableName);
      if (count <= 0) {
        logger.w("Upgrade4to5 - $oldTopicTableName delete - fail");
      } else {
        logger.i("Upgrade4to5 - $oldTopicTableName delete - success");
      }
    } else {
      logger.w("Upgrade4to5 - delete $oldTopicTableName no exist");
    }
    // subscriber
    upgradeTipStream?.add("... (7/7)");
    String oldSubscriberTableName = 'subscriber';
    if (await DB.checkTableExists(db, oldSubscriberTableName)) {
      int count = await db.delete(oldSubscriberTableName);
      if (count <= 0) {
        logger.w("Upgrade4to5 - $oldSubscriberTableName delete - fail");
      } else {
        logger.i("Upgrade4to5 - $oldSubscriberTableName delete - success");
      }
    } else {
      logger.w("Upgrade4to5 - delete $oldSubscriberTableName no exist");
    }
    // messages
    upgradeTipStream?.add(".... (7/7)");
    String oldMessageTableName = 'Messages';
    if (await DB.checkTableExists(db, oldMessageTableName)) {
      int count = await db.delete(oldMessageTableName);
      if (count <= 0) {
        logger.w("Upgrade4to5 - $oldMessageTableName delete - fail");
      } else {
        logger.i("Upgrade4to5 - $oldMessageTableName delete - success");
      }
    } else {
      logger.w("Upgrade4to5 - delete $oldMessageTableName no exist");
    }
  }
}
