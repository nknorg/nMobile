import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/message_piece.dart';
import 'package:nmobile/storages/private_group.dart';
import 'package:nmobile/storages/private_group_item.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'; // TODO:GG 这个是不是要注意下?以及所有的import

// TODO:GG 应该就不是升级，是迁移了，版本号还是改成7？
// TODO:GG 各个表名要修改吗？
// TODO:GG 尽量不要importSchema
// TODO:GG 外部调用，记得tryCache和tryTimes
class Upgrade6to7 {
  static Future upgradeDeviceInfo(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // contact_address (VARCHAR(200)) -> contact_address (VARCHAR(100))(NOT EMPTY)
    // device_id (TEXT) -> device_id (VARCHAR(200))(NOT EMPTY)
    // contact.device_token (TEXT) -> device_token (TEXT)(NOT NULL)
    // update_at/create_at (BIGINT) -> online_at (BIGINT)(NOT EMPTY)
    // data (TEXT) -> data (TEXT)(NOT NULL)

    upgradeTipSink?.add(". (1/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, DeviceInfoStorage.tableName))) {
      upgradeTipSink?.add(".. (1/9)");
      await DeviceInfoStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (1/9)");

    // table(v5)
    String oldTableName = "DeviceInfo";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (1/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        // createAt
        int newCreateAt = int.tryParse(result["create_at"] ?? "") ?? 0;
        if (newCreateAt == 0) {
          logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - oldCreateAt null - data:$result");
          newCreateAt = DateTime.now().millisecondsSinceEpoch - 1 * 24 * 60 * 60 * 1000; // 1d
        }
        // updateAt
        int newUpdateAt = int.tryParse(result["update_at"] ?? "") ?? 0;
        if ((newUpdateAt == 0) || (newUpdateAt < newCreateAt)) {
          logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - oldUpdateAt null - data:$result");
          newUpdateAt = newCreateAt;
        }
        // contactAddress
        String? oldContactAddress = result["contact_address"]?.toString();
        if ((oldContactAddress == null) || oldContactAddress.isEmpty) {
          logger.e("Upgrade6to7 - ${DeviceInfoStorage.tableName} - oldContactAddress null - data:$result");
          continue;
        }
        String newContactAddress = (oldContactAddress.length <= 100) ? oldContactAddress : "";
        if (newContactAddress.isEmpty) {
          logger.e("Upgrade6to7 - ${DeviceInfoStorage.tableName} - newContactAddress null - data:$result");
          continue;
        }
        // deviceId
        String? oldDeviceId = result["device_id"]?.toString().replaceAll("\n", "").trim();
        if ((oldDeviceId == null) || oldDeviceId.isEmpty) {
          logger.e("Upgrade6to7 - ${DeviceInfoStorage.tableName} - oldContactAddress null - data:$result");
          continue;
        }
        String newDeviceId = (oldDeviceId.length <= 200) ? oldDeviceId : "";
        if (newDeviceId.isEmpty) {
          logger.e("Upgrade6to7 - ${DeviceInfoStorage.tableName} - newDeviceId null - data:$result");
          continue;
        }
        // deviceToken
        String newDeviceToken = ""; // set in contact
        // onlineAt
        int newOnlineAt = newUpdateAt;
        // data
        Map<String, dynamic> _oldData = Map();
        if (result['data']?.toString().isNotEmpty == true) {
          _oldData = Util.jsonFormatMap(result['data']?.toString()) ?? Map();
        }
        Map<String, dynamic> _newData = Map();
        _newData['appName'] = _oldData['appName'];
        _newData['appVersion'] = _oldData['appVersion'];
        _newData['platform'] = _oldData['platform'];
        _newData['platformVersion'] = _oldData['platformVersion'];
        String newData = "{}";
        try {
          newData = jsonEncode(_newData);
        } catch (e) {
          logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - newData wrong - data:$result - error:${e.toString()}");
        }
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            DeviceInfoStorage.tableName,
            columns: ['id'],
            where: 'contact_address = ? AND device_id = ?',
            whereArgs: [newContactAddress, newDeviceId],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'contact_address': newContactAddress,
          'device_id': newDeviceId,
          'device_token': newDeviceToken,
          'online_at': newOnlineAt,
          'data': newData,
        };
        try {
          int id = await db.insert(DeviceInfoStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${DeviceInfoStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (1/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${DeviceInfoStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${DeviceInfoStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${DeviceInfoStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradeContact(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // address (VARCHAR(200)) -> address (VARCHAR(100))(NOT EMPTY)
    // .data[nknWalletAddress] (String) -> wallet_address (VARCHAR(100))(NOT NULL)
    // avatar (TEXT) -> avatar (TEXT)
    // first_name (VARCHAR(50)) -> first_name (VARCHAR(50))(NOT EMPTY)
    // last_name (VARCHAR(50)) -> last_name (VARCHAR(50))(NOT NULL)
    // .data[remarkName/firstName] (String) -> remark_name (VARCHAR(50))(NOT NULL)
    // type (INT) -> type (INT)(NOT EMPTY)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // data (TEXT) -> data (TEXT)(NOT NULL)

    upgradeTipSink?.add(". (2/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, ContactStorage.tableName))) {
      upgradeTipSink?.add(".. (2/9)");
      await ContactStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${ContactStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (2/9)");

    // table(v5)
    String oldTableName = "Contact_2";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${ContactStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (2/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${ContactStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        // createAt
        int newCreateAt = int.tryParse(result["create_at"] ?? "") ?? 0;
        if (newCreateAt == 0) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - oldCreateAt null - data:$result");
          newCreateAt = DateTime.now().millisecondsSinceEpoch - 1 * 24 * 60 * 60 * 1000; // 1d
        }
        // updateAt
        int newUpdateAt = int.tryParse(result["update_at"] ?? "") ?? 0;
        if ((newUpdateAt == 0) || (newUpdateAt < newCreateAt)) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - oldUpdateAt null - data:$result");
          newUpdateAt = newCreateAt;
        }
        // address
        String? oldAddress = result["address"]?.toString();
        if ((oldAddress == null) || oldAddress.isEmpty) {
          logger.e("Upgrade6to7 - ${ContactStorage.tableName} - oldAddress null - data:$result");
          continue;
        }
        String newAddress = (oldAddress.length <= 100) ? oldAddress : "";
        if (newAddress.isEmpty) {
          logger.e("Upgrade6to7 - ${ContactStorage.tableName} - newAddress null - data:$result");
          continue;
        }
        // avatar
        String? newAvatar = Path.convert2Local(result["avatar"]?.toString());
        // firstName
        String newFirstName = result["first_name"]?.toString() ?? "";
        if (newFirstName.isEmpty) {
          logger.e("Upgrade6to7 - ${ContactStorage.tableName} - oldFirstName wrong - data:$result");
          if (newAddress.length <= 6) {
            newFirstName = newAddress;
          } else {
            var index = newAddress.lastIndexOf('.');
            if (index < 0) {
              newFirstName = newAddress.substring(0, 6);
            } else if (newAddress.length > (index + 7)) {
              newFirstName = newAddress.substring(0, index + 7);
            } else {
              newFirstName = newAddress;
            }
          }
        }
        // lastName
        String newLastName = result["last_name"]?.toString() ?? "";
        // type
        int newType = int.tryParse(result["type"] ?? "") ?? 0; // ContactType.none
        // isTop
        int newIsTop = 0;
        // options
        OptionsSchema? _newOptions;
        if (result['options']?.toString().isNotEmpty == true) {
          Map<String, dynamic>? map = Util.jsonFormatMap(result['options']?.toString());
          _newOptions = OptionsSchema.fromMap(map ?? Map());
        } else {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - oldOptions wrong - data:$result");
        }
        _newOptions = _newOptions ?? OptionsSchema();
        String newOptions = "{}";
        try {
          newOptions = jsonEncode(_newOptions.toMap());
        } catch (e) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - newOptions wrong - data:$result - error:${e.toString()}");
        }
        // data
        Map<String, dynamic> _oldData = Map();
        if (result['data']?.toString().isNotEmpty == true) {
          _oldData = Util.jsonFormatMap(result['data']?.toString()) ?? Map();
        }
        Map<String, dynamic> _newData = Map();
        _newData["profileVersion"] = result["profile_version"]?.toString();
        _newData['remarkAvatar'] = _oldData['avatar'] ?? _oldData['remarkAvatar'] ?? _oldData['remark_avatar'];
        _newData['notes'] = _oldData['notes'];
        _newData['mappedAddress'] = _oldData['mappedAddress'];
        _newData['tipNotification'] = 1; // or Settings."chat_tip_notification:$client_address:$targetId" (String(0/1)) -> .data[tipNotification] (Int(0/1))
        _newData['receivedMessages'] = {}; // set when message delete
        String newData = "{}";
        try {
          newData = jsonEncode(_newData);
        } catch (e) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - newData wrong - data:$result - error:${e.toString()}");
        }
        // walletAddress
        String newWalletAddress = _oldData["nknWalletAddress"]?.toString() ?? ""; // no refresh
        // remarkName
        String newRemarkName = (_oldData["firstName"] ?? _oldData["first_name"] ?? _oldData["remarkName"] ?? _oldData["remark_name"])?.toString() ?? "";
        // deviceToken
        String deviceToken = (result["device_token"]?.toString() ?? "").replaceAll("\n", "").trim();
        if (deviceToken.isNotEmpty && (deviceToken.startsWith("[APNS]:") || deviceToken.startsWith("[FCM]:"))) {
          try {
            int? count = await db.update(
              DeviceInfoStorage.tableName,
              {
                'device_token': deviceToken,
              },
              where: 'contact_address = ?',
              whereArgs: [newAddress],
            );
            if ((count == null) || (count <= 0)) logger.w("Upgrade6to7 - ${ContactStorage.tableName} - deviceToken no set - old:$result");
          } catch (e) {
            logger.w("Upgrade6to7 - ${ContactStorage.tableName} - deviceToken error - old:$result - error:${e.toString()}");
          }
        }
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            ContactStorage.tableName,
            columns: ['id'],
            where: 'address = ?',
            whereArgs: [newAddress],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${ContactStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'address': newAddress,
          'wallet_address': newWalletAddress,
          'avatar': newAvatar,
          'first_name': newFirstName,
          'last_name': newLastName,
          'remark_name': newRemarkName,
          'type': newType,
          'is_top': newIsTop,
          'options': newOptions,
          'data': newData,
        };
        try {
          int id = await db.insert(ContactStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${ContactStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${ContactStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (2/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${ContactStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${ContactStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${ContactStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradeTopic(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // topic (VARCHAR(200)) -> topic_id (VARCHAR(100))(NOT EMPTY)
    // type (INT) -> type (INT)(NOT EMPTY)
    // joined (BOOLEAN DEFAULT 0) -> joined (BOOLEAN DEFAULT 0)(NOT NULL)
    // subscribe_at (BIGINT) -> subscribe_at (BIGINT)
    // expire_height (BIGINT) -> expire_height (BIGINT)
    // avatar (TEXT) -> avatar (TEXT)
    // count (INT) -> count (INT)(NOT NULL)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // data (TEXT) -> data (TEXT)(NOT NULL)

    upgradeTipSink?.add(". (3/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, TopicStorage.tableName))) {
      upgradeTipSink?.add(".. (3/9)");
      await TopicStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${TopicStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (3/9)");

    // table(v5)
    String oldTableName = "Topic_3";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${TopicStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (3/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${TopicStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        // createAt
        int newCreateAt = int.tryParse(result["create_at"] ?? "") ?? 0;
        if (newCreateAt == 0) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - oldCreateAt null - data:$result");
          newCreateAt = DateTime.now().millisecondsSinceEpoch - 1 * 24 * 60 * 60 * 1000; // 1d
        }
        // updateAt
        int newUpdateAt = int.tryParse(result["update_at"] ?? "") ?? 0;
        if ((newUpdateAt == 0) || (newUpdateAt < newCreateAt)) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - oldUpdateAt null - data:$result");
          newUpdateAt = newCreateAt;
        }
        // topicId
        String? oldTopicId = result["topic"]?.toString();
        if ((oldTopicId == null) || oldTopicId.isEmpty) {
          logger.e("Upgrade6to7 - ${TopicStorage.tableName} - oldTopicId null - data:$result");
          continue;
        }
        String newTopicId = (oldTopicId.length <= 100) ? oldTopicId : "";
        if (newTopicId.isEmpty) {
          logger.e("Upgrade6to7 - ${TopicStorage.tableName} - newTopicId null - data:$result");
          continue;
        }
        // type
        int newType = int.tryParse(result["type"] ?? "") ?? 0; // 1/2
        if ((newType != 1) && (newType != 2)) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - oldType null - data:$result");
          newType = RegExp(r'\.[0-9A-Fa-f]{64}$').hasMatch(newTopicId) ? 2 : 1;
        }
        // joined
        int newJoined = (result["joined"]?.toString() == '1') ? 1 : 0;
        // subscribeAt
        int? newSubscribeAt = int.tryParse(result["subscribe_at"] ?? "");
        // expireHeight
        int? newExpireHeight = int.tryParse(result["expire_height"] ?? "");
        // avatar
        String? newAvatar = Path.convert2Local(result["avatar"]?.toString());
        // count
        int newCount = int.tryParse(result["count"] ?? "") ?? 0;
        // isTop
        int newIsTop = 0;
        // options
        OptionsSchema? _newOptions;
        if (result['options']?.toString().isNotEmpty == true) {
          Map<String, dynamic>? map = Util.jsonFormatMap(result['options']?.toString());
          _newOptions = OptionsSchema.fromMap(map ?? Map());
        } else {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - oldOptions wrong - data:$result");
        }
        _newOptions = _newOptions ?? OptionsSchema();
        if ((result['theme_id'] != null) && (result['theme_id'] is int) && (result['theme_id'] != 0)) {
          _newOptions.avatarBgColor = Color(result['theme_id']);
        }
        String newOptions = "{}";
        try {
          newOptions = jsonEncode(_newOptions.toMap());
        } catch (e) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - newOptions wrong - data:$result - error:${e.toString()}");
        }
        // data
        String newData = "{}"; // clear temps
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            TopicStorage.tableName,
            columns: ['id'],
            where: 'topic_id = ?',
            whereArgs: [newTopicId],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${TopicStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'topic_id': newTopicId,
          'type': newType,
          'joined': newJoined,
          'subscribe_at': newSubscribeAt,
          'expire_height': newExpireHeight,
          'avatar': newAvatar,
          'count': newCount,
          'is_top': newIsTop,
          'options': newOptions,
          'data': newData,
        };
        try {
          int id = await db.insert(TopicStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${TopicStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${TopicStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (3/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${TopicStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${TopicStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradeSubscriber(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // topic (VARCHAR(200)) -> topic_id (VARCHAR(100))(NOT EMPTY)
    // chat_id (VARCHAR(200)) -> contact_address (VARCHAR(100))(NOT EMPTY)
    // status (INT) -> status (INT)(NOT EMPTY)
    // perm_page (INT) -> perm_page (INT)
    // data (TEXT) -> data (TEXT)(NOT NULL)

    upgradeTipSink?.add(". (4/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, SubscriberStorage.tableName))) {
      upgradeTipSink?.add(".. (4/9)");
      await SubscriberStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (4/9)");

    // table(v5)
    String oldTableName = "Subscriber_3";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (4/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        // createAt
        int newCreateAt = int.tryParse(result["create_at"] ?? "") ?? 0;
        if (newCreateAt == 0) {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - oldCreateAt null - data:$result");
          newCreateAt = DateTime.now().millisecondsSinceEpoch - 1 * 24 * 60 * 60 * 1000; // 1d
        }
        // updateAt
        int newUpdateAt = int.tryParse(result["update_at"] ?? "") ?? 0;
        if ((newUpdateAt == 0) || (newUpdateAt < newCreateAt)) {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - oldUpdateAt null - data:$result");
          newUpdateAt = newCreateAt;
        }
        // topicId
        String? oldTopicId = result["topic"]?.toString();
        if ((oldTopicId == null) || oldTopicId.isEmpty) {
          logger.e("Upgrade6to7 - ${SubscriberStorage.tableName} - oldTopicId null - data:$result");
          continue;
        }
        String newTopicId = (oldTopicId.length <= 100) ? oldTopicId : "";
        if (newTopicId.isEmpty) {
          logger.e("Upgrade6to7 - ${SubscriberStorage.tableName} - newTopicId null - data:$result");
          continue;
        }
        // contactAddress
        String? oldContactAddress = result["chat_id"]?.toString();
        if ((oldContactAddress == null) || oldContactAddress.isEmpty) {
          logger.e("Upgrade6to7 - ${SubscriberStorage.tableName} - oldContactAddress null - data:$result");
          continue;
        }
        String newContactAddress = (oldContactAddress.length <= 100) ? oldContactAddress : "";
        if (newContactAddress.isEmpty) {
          logger.e("Upgrade6to7 - ${SubscriberStorage.tableName} - newContactAddress null - data:$result");
          continue;
        }
        // status
        int newStatus = int.tryParse(result["status"] ?? "") ?? 0; // SubscriberStatus.None
        // permPage
        int? newPermPage = int.tryParse(result["perm_page"] ?? "");
        // data
        String newData = "{}"; // clear temps
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            SubscriberStorage.tableName,
            columns: ['id'],
            where: 'topic_id = ? AND contact_address = ?',
            whereArgs: [newTopicId, newContactAddress],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'topic_id': newTopicId,
          'contact_address': newContactAddress,
          'status': newStatus,
          'perm_page': newPermPage,
          'data': newData,
        };
        try {
          int id = await db.insert(SubscriberStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${SubscriberStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (4/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradePrivateGroup(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // group_id (VARCHAR(200)) -> group_id (VARCHAR(100))(NOT EMPTY)
    // type (INT) -> type (INT)
    // name (VARCHAR(200)) -> name (VARCHAR(100))(NOT EMPTY)
    // count (INT) -> count (INT)(NOT NULL)
    // avatar (TEXT) -> avatar (TEXT)
    // joined (BOOLEAN DEFAULT 0) -> joined (BOOLEAN DEFAULT 0)(NOT NULL)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // data (TEXT) -> data (TEXT)(NOT NULL)

    upgradeTipSink?.add(". (5/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, PrivateGroupStorage.tableName))) {
      upgradeTipSink?.add(".. (5/9)");
      await PrivateGroupStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (5/9)");

    // table(v5)
    String oldTableName = "PrivateGroup";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (5/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        // createAt
        int newCreateAt = int.tryParse(result["create_at"] ?? "") ?? 0;
        if (newCreateAt == 0) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - oldCreateAt null - data:$result");
          newCreateAt = DateTime.now().millisecondsSinceEpoch - 1 * 24 * 60 * 60 * 1000; // 1d
        }
        // updateAt
        int newUpdateAt = int.tryParse(result["update_at"] ?? "") ?? 0;
        if ((newUpdateAt == 0) || (newUpdateAt < newCreateAt)) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - oldUpdateAt null - data:$result");
          newUpdateAt = newCreateAt;
        }
        // groupId
        String? oldGroupId = result["group_id"]?.toString();
        if ((oldGroupId == null) || oldGroupId.isEmpty) {
          logger.e("Upgrade6to7 - ${PrivateGroupStorage.tableName} - oldGroupId null - data:$result");
          continue;
        }
        String newGroupId = (oldGroupId.length <= 100) ? oldGroupId : "";
        if (newGroupId.isEmpty) {
          logger.e("Upgrade6to7 - ${PrivateGroupStorage.tableName} - newGroupId null - data:$result");
          continue;
        }
        // type
        int newType = 0;
        // name
        String newName = result["name"]?.toString() ?? "";
        if (newName.isEmpty) {
          logger.e("Upgrade6to7 - ${PrivateGroupStorage.tableName} - oldName wrong - data:$result");
          newName = newGroupId;
        }
        // count
        int newCount = int.tryParse(result["count"] ?? "") ?? 0;
        // avatar
        String? newAvatar = Path.convert2Local(result["avatar"]?.toString());
        // joined
        int newJoined = (result["joined"]?.toString() == '1') ? 1 : 0;
        // isTop
        int newIsTop = 0;
        // options
        OptionsSchema? _newOptions;
        if (result['options']?.toString().isNotEmpty == true) {
          Map<String, dynamic>? map = Util.jsonFormatMap(result['options']?.toString());
          _newOptions = OptionsSchema.fromMap(map ?? Map());
        } else {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - oldOptions wrong - data:$result");
        }
        _newOptions = _newOptions ?? OptionsSchema();
        String newOptions = "{}";
        try {
          newOptions = jsonEncode(_newOptions.toMap());
        } catch (e) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - newOptions wrong - data:$result - error:${e.toString()}");
        }
        // data
        Map<String, dynamic> _oldData = Map();
        if (result['data']?.toString().isNotEmpty == true) {
          _oldData = Util.jsonFormatMap(result['data']?.toString()) ?? Map();
        }
        Map<String, dynamic> _newData = Map();
        _newData['signature'] = _oldData['signature'];
        _newData["version"] = result["version"]?.toString();
        _newData['quit_at_version_commits'] = _oldData['quit_at_version_commits'];
        _newData['receivedMessages'] = {}; // set when message delete
        String newData = "{}";
        try {
          newData = jsonEncode(_newData);
        } catch (e) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - newData wrong - data:$result - error:${e.toString()}");
        }
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            PrivateGroupStorage.tableName,
            columns: ['id'],
            where: 'group_id = ?',
            whereArgs: [newGroupId],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'group_id': newGroupId,
          'type': newType,
          'name': newName,
          'count': newCount,
          'avatar': newAvatar,
          'joined': newJoined,
          'is_top': newIsTop,
          'options': newOptions,
          'data': newData,
        };
        try {
          int id = await db.insert(PrivateGroupStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${PrivateGroupStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (5/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${PrivateGroupStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${PrivateGroupStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradePrivateGroupItem(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // group_id (VARCHAR(200)) -> group_id (VARCHAR(100))(NOT EMPTY)
    // permission (INT) -> permission (INT)(NOT EMPTY)
    // expires_at (BIGINT) -> expires_at (BIGINT)
    // inviter (VARCHAR(200)) -> inviter (VARCHAR(100))
    // invitee (VARCHAR(200)) -> invitee (VARCHAR(100))
    // inviter_raw_data (TEXT) -> inviter_raw_data (TEXT)
    // invitee_raw_data (TEXT) -> invitee_raw_data (TEXT)
    // inviter_signature (VARCHAR(200)) -> inviter_signature (VARCHAR(200))
    // invitee_signature (VARCHAR(200)) -> invitee_signature (VARCHAR(200))
    // data (TEXT) -> data (TEXT)(NOT NULL)

    upgradeTipSink?.add(". (6/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, PrivateGroupItemStorage.tableName))) {
      upgradeTipSink?.add(".. (6/9)");
      await PrivateGroupItemStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (6/9)");

    // table(v5)
    String oldTableName = "PrivateGroupList";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (6/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        // groupId
        String? oldGroupId = result["group_id"]?.toString();
        if ((oldGroupId == null) || oldGroupId.isEmpty) {
          logger.e("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - oldGroupId null - data:$result");
          continue;
        }
        String newGroupId = (oldGroupId.length <= 100) ? oldGroupId : "";
        if (newGroupId.isEmpty) {
          logger.e("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - newGroupId null - data:$result");
          continue;
        }
        // permission
        int newPermission = int.tryParse(result["permission"] ?? "") ?? 0; // PrivateGroupItemPerm.None
        // expiresAt
        int? newExpiresAt = int.tryParse(result["expires_at"] ?? "");
        // inviter
        String? newInviter = result["inviter"];
        // newInvitee
        String? newInvitee = result["invitee"];
        // inviterRawData
        String? newInviterRawData = result["inviter_raw_data"];
        // inviteeRawData
        String? newInviteeRawData = result["invitee_raw_data"];
        // inviterSignature
        String? newInviterSignature = result["inviter_signature"];
        // inviteeSignature
        String? newInviteeSignature = result["invitee_signature"];
        // data
        String newData = "{}"; // nothing
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            PrivateGroupItemStorage.tableName,
            columns: ['id'],
            where: 'group_id = ? AND invitee = ?',
            whereArgs: [newGroupId, newInvitee],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'group_id': newGroupId,
          'permission': newPermission,
          'expires_at': newExpiresAt,
          'inviter': newInviter,
          'invitee': newInvitee,
          'inviter_raw_data': newInviterRawData,
          'invitee_raw_data': newInviteeRawData,
          'inviter_signature': newInviterSignature,
          'invitee_signature': newInviteeSignature,
          'data': newData,
        };
        try {
          int id = await db.insert(PrivateGroupItemStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (6/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradeMessage(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // pid (VARCHAR(300)) -> pid (VARCHAR(100))(NOT EMPTY)
    // msg_id (VARCHAR(300)) -> msg_id (VARCHAR(100))(NOT EMPTY)
    // ??? -> device_id (VARCHAR(200))
    // ??? -> queue_id (BIGINT)
    // sender (VARCHAR(200)) -> sender (VARCHAR(100))(NOT EMPTY)
    // target_id/(group_id/topic/receiver) (VARCHAR(200)) -> target_id (VARCHAR(100))(NOT EMPTY)
    // (group_id/topic/receiver) -> target_type (INT)(NOT EMPTY)
    // is_outbound (BOOLEAN DEFAULT 0) -> is_outbound (BOOLEAN DEFAULT 0)(NOT EMPTY)
    // status (INT) -> status (INT)(NOT EMPTY)
    // send_at (BIGINT) -> send_at (BIGINT)(NOT EMPTY)
    // receive_at (BIGINT) -> receive_at (BIGINT)
    // is_delete (BOOLEAN DEFAULT 0) -> is_delete (BOOLEAN DEFAULT 0)(NOT EMPTY)
    // delete_at (BIGINT) -> delete_at (BIGINT)
    // type (VARCHAR(30)) -> type (VARCHAR(30))(NOT EMPTY)
    // content (TEXT) -> content (TEXT)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // ??? -> data (TEXT)

    upgradeTipSink?.add(". (7/9)");

    // table(v7)
    if (!(await DB.checkTableExists(db, MessageStorage.tableName))) {
      upgradeTipSink?.add(".. (7/9)");
      await MessageStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${MessageStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (7/9)");

    // table(v5)
    String oldTableName = "Messages_2";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${MessageStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (7/9)");

    // total
    int totalRawCount = 0;
    try {
      totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;
    } catch (e) {
      logger.w("Upgrade6to7 - ${MessageStorage.tableName} - totalRawCount error - error:${e.toString()}");
    }

    // convert(v5->v7)
    int total = 0;
    final limit = 50;
    Map<String, int> receivedMessages = {};
    for (int offset = 0; true; offset += limit) {
      // items
      List<Map<String, dynamic>>? results = (await db.query(
            oldTableName,
            columns: ['*'],
            orderBy: 'id ASC',
            offset: offset,
            limit: limit,
          )) ??
          [];
      // item
      for (int i = 0; i < results.length; i++) {
        Map<String, dynamic> result = results[i];
        int nowAt = DateTime.now().millisecondsSinceEpoch;
        // pid
        var newPid = result["pid"];
        // msgId
        String? oldMsgId = result["msg_id"]?.toString();
        if ((oldMsgId == null) || oldMsgId.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldMsgId null - data:$result");
          continue;
        }
        String newMsgId = (oldMsgId.length <= 100) ? oldMsgId : "";
        if (newMsgId.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - newMsgId null - data:$result");
          continue;
        }
        // deviceId
        String newDeviceId = "";
        // queueId
        int newQueueId = 0;
        // sender
        String? oldSender = result["sender"]?.toString();
        if ((oldSender == null) || oldSender.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldSender null - data:$result");
          continue;
        }
        String newSender = (oldSender.length <= 100) ? oldSender : "";
        if (newSender.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - newSenderId null - data:$result");
          continue;
        }
        // targetId
        String? _oldGroupId = (result["group_id"]?.toString() ?? "").isNotEmpty ? result["group_id"]?.toString() : null;
        String? _oldTopicId = (result["topic"]?.toString() ?? "").isNotEmpty ? result["topic"]?.toString() : null;
        String? _oldReceiver = (result["receiver"]?.toString() ?? "").isNotEmpty ? result["receiver"]?.toString() : null;
        String? _oldTargetId = (result["target_id"]?.toString() ?? "").isNotEmpty ? result["target_id"]?.toString() : null;
        String? oldTargetId = _oldGroupId ?? _oldTopicId ?? _oldReceiver ?? _oldTargetId;
        if ((oldTargetId == null) || oldTargetId.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldTargetId null - data:$result");
          continue;
        }
        String newTargetId = (oldTargetId.length <= 100) ? oldTargetId : "";
        if (newTargetId.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - newTargetId null - data:$result");
          continue;
        }
        // targetType
        int newTargetType;
        if (_oldGroupId != null) {
          newTargetType = 3;
        } else if (_oldTopicId != null) {
          newTargetType = 2;
        } else {
          newTargetType = 1;
        }
        // isOutbound
        int newIsOutbound = (result["is_outbound"]?.toString() == '1') ? 1 : 0;
        // status
        int? oldStatus = int.tryParse(result["status"] ?? "");
        if (oldStatus == null) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldStatus null - data:$result");
          continue;
        }
        int? newStatus;
        switch (oldStatus) {
          case 100: // Sending
            newStatus = 0;
            break;
          case 110: // Error
            newStatus = -10;
            break;
          case 120: // Success
          // newStatus = 10; // Success
          // break;
          case 130: // Receipt
          case 200: // Received
            newStatus = 20; // Receipt
            break;
          case 310: // Read
            newStatus = 30;
            break;
        }
        if (newStatus == null) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - newStatus null - data:$result");
          continue;
        } else if ((newPid == null) && (newStatus >= 0)) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldPid null - data:$result");
          continue;
        }
        // sendAt
        int newSendAt = int.tryParse(result["send_at"] ?? "") ?? 0;
        if (newSendAt == 0) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldSendAt null - data:$result");
          continue;
        }
        // receiveAt
        int newReceiveAt = int.tryParse(result["receive_at"] ?? "") ?? newSendAt;
        // isDelete
        int newIsDelete = (result["is_delete"]?.toString() == '1') ? 1 : 0;
        int? newDeleteAt = int.tryParse(result["delete_at"] ?? "");
        if ((newIsDelete == 1) || ((newDeleteAt != null) && (newDeleteAt <= nowAt))) {
          if (newStatus > 0) {
            int gap = 10 * 24 * 60 * 60 * 1000; // 20d
            if ((newSendAt < (nowAt - gap)) || (newReceiveAt < (nowAt - gap))) {
              logger.i("Upgrade6to7 - ${MessageStorage.tableName} - delete now (too old) - data:$result");
              continue;
            } else {
              logger.i("Upgrade6to7 - ${MessageStorage.tableName} - delete after (loop over) - data:$result");
              receivedMessages.addAll({newMsgId: newReceiveAt}); // TODO:GG 还是当下弄比较好？
              continue;
            }
          } else {
            logger.i("Upgrade6to7 - ${MessageStorage.tableName} - delete skip (burning progress) - data:$result");
          }
        }
        // type
        String oldContentType = result["type"]?.toString() ?? "";
        String newContentType = "";
        switch (oldContentType) {
          case "event:contactOptions":
            newContentType = "contact:options";
            break;
          case "media":
          case "nknImage":
            newContentType = "image";
            break;
          case "event:subscribe":
            newContentType = "topic:subscribe";
            break;
          case "event:channelInvitation":
            newContentType = "topic:invitation";
            break;
          case "text":
          case "textExtension":
          case "ipfs":
          case "file":
          case "image":
          case "audio":
          case "video":
          case "privateGroup:invitation":
          case "privateGroup:subscribe":
            newContentType = oldContentType;
            break;
          default:
            // nothing
            break;
        }
        if (newContentType.isEmpty) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - newContentType null - data:$result");
          continue;
        }
        // content
        var newContent = result["content"];
        if ((newContent == null) && ((newContentType == "text") || (newContentType == "textExtension") || (newContentType == "image") || (newContentType == "audio"))) {
          logger.e("Upgrade6to7 - ${MessageStorage.tableName} - oldContent null - data:$result");
          continue;
        }
        // options
        Map<String, dynamic> _newOptions = Map();
        if (result['options']?.toString().isNotEmpty == true) {
          _newOptions = Util.jsonFormatMap(result['options']?.toString()) ?? Map();
        }
        if (newIsOutbound == 1) _newOptions["sendSuccessAt"] = newSendAt;
        String newOptions = "{}";
        try {
          newOptions = jsonEncode(_newOptions);
        } catch (e) {
          logger.w("Upgrade6to7 - ${MessageStorage.tableName} - newOptions wrong - data:$result - error:${e.toString()}");
        }
        // data
        String? newData; // nothing
        // duplicated
        try {
          List<Map<String, dynamic>>? duplicated = await db.query(
            MessageStorage.tableName,
            columns: ['id'],
            where: 'msg_id = ?',
            whereArgs: [newMsgId],
            offset: 0,
            limit: 1,
          );
          if ((duplicated != null) && duplicated.isNotEmpty) {
            logger.w("Upgrade6to7 - ${MessageStorage.tableName} - insert duplicated - old:$result - exist:$duplicated");
            continue;
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${MessageStorage.tableName} - duplicated query error - error:${e.toString()}");
        }
        // insert
        Map<String, dynamic> entity = {
          'pid': newPid,
          'msg_id': newMsgId,
          'device_id': newDeviceId,
          'queue_id': newQueueId,
          'sender': newSender,
          'target_id': newTargetId,
          'target_type': newTargetType,
          'is_outbound': newIsOutbound,
          'status': newStatus,
          'send_at': newSendAt,
          'receive_at': newReceiveAt,
          'is_delete': newIsDelete,
          'delete_at': newDeleteAt,
          'type': newContentType,
          'content': newContent,
          'options': newOptions,
          'data': newData,
        };
        try {
          int id = await db.insert(MessageStorage.tableName, entity);
          if (id > 0) {
            logger.d("Upgrade6to7 - ${MessageStorage.tableName} - insert success - data:$entity");
            total++;
          } else {
            logger.w("Upgrade6to7 - ${MessageStorage.tableName} - insert fail - data:$entity");
          }
        } catch (e) {
          logger.w("Upgrade6to7 - ${MessageStorage.tableName} - insert error - error:${e.toString()}");
        }
      }
      upgradeTipSink?.add("..... (7/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${MessageStorage.tableName} - $oldTableName loop over(warn) - progress:$total/${offset + limit}/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${MessageStorage.tableName} - $oldTableName loop over(ok) - progress:$total/${offset + limit}/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${MessageStorage.tableName} - $oldTableName loop next - progress:$total/${offset + limit}/$totalRawCount");
      }
    }
  }

  static Future upgradeMessagePiece(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    upgradeTipSink?.add(". (8/9)");
    // just create table
    if (!(await DB.checkTableExists(db, MessagePieceStorage.tableName))) {
      upgradeTipSink?.add(".. (8/9)");
      await MessagePieceStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${MessagePieceStorage.tableName} - exist");
    }
  }

  static Future upgradeSession(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // target_id (VARCHAR(200)) -> target_id (VARCHAR(100))(NOT EMPTY)
    // type (INT) -> type (INT)(NOT EMPTY)
    // last_message_at (BIGINT) -> last_message_at (BIGINT)(NOT EMPTY)
    // last_message_options (TEXT) -> last_message_options (TEXT)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(NOT EMPTY)
    // un_read_count (INT) -> un_read_count (INT)(NOT NULL) ---> 需要queryCount
    // ??? -> data (TEXT)(NOT NULL) ----> reset。只有一个senderName，直接从last_message_options里找contact然后赋值

    upgradeTipSink?.add(". (9/9)");

    // TODO:GG db
  }

  static Future deletesOldTables(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // TODO:GG db
  }
}
