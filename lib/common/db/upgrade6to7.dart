import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/schema/option.dart';
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
    // device_id (TEXT) -> device_id (VARCHAR(200))(NOT EMPTY) ---> 注意如果是empty就舍弃了
    // contact.device_token (TEXT) -> device_token (TEXT)(NOT NULL) ---> 是否带有[XXX:]的前缀，不带就舍弃。 如果contact有token，那么也可以健一个device_id为empty的，把token塞进去?????
    // update_at/create_at (BIGINT) -> online_at (BIGINT)(NOT EMPTY)
    // data (TEXT) -> data (TEXT)(NOT NULL) ----> equal。旧的值直接拷贝，新的临时创建

    upgradeTipSink?.add(". (1/9)");

    // TODO:GG db
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
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(const=0)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // data (TEXT) -> data (TEXT)(NOT NULL) ----> reset。还有notes,mappedAddress
    ///----------------------
    // profile_version (VARCHAR(300)) -> .data[profileVersion] (String)
    // .data[remarkAvatar/avatar] (TEXT) -> .data[remarkAvatar] (TEXT)
    // Settings."chat_tip_notification:$client_address:$targetId" (String(0/1)) -> .data[tipNotification] (Int(0/1))
    // 消息删除的时候，根据receiveAt，来判断是否插入 (???) -> .data[receivedMessages] (Map<String, int>)
    // device_token (TEXT) -> deviceInfo.device_token (TEXT)

    upgradeTipSink?.add(". (2/9)");

    // TODO:GG db
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
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(const=0)
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
          logger.e("Upgrade6to7 - ${TopicStorage.tableName} - newTopicId wrong - data:$result");
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
          logger.w("Upgrade6to7 - ${TopicStorage.tableName} - newOptions wrong - data:$result");
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
          logger.e("Upgrade6to7 - ${SubscriberStorage.tableName} - newTopicId wrong - data:$result");
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
          logger.e("Upgrade6to7 - ${SubscriberStorage.tableName} - newContactAddress wrong - data:$result");
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
    // type (INT) -> type (INT)(const=0)
    // name (VARCHAR(200)) -> name (VARCHAR(100))(NOT EMPTY)
    // count (INT) -> count (INT)(NOT NULL)
    // avatar (TEXT) -> avatar (TEXT)
    // joined (BOOLEAN DEFAULT 0) -> joined (BOOLEAN DEFAULT 0)(NOT NULL)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(const=0)
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
          logger.e("Upgrade6to7 - ${PrivateGroupStorage.tableName} - newGroupId wrong - data:$result");
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
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - newOptions wrong - data:$result");
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
          logger.w("Upgrade6to7 - ${PrivateGroupStorage.tableName} - newData wrong - data:$result");
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
          logger.e("Upgrade6to7 - ${PrivateGroupItemStorage.tableName} - newGroupId wrong - data:$result");
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
    // pid (VARCHAR(300)) -> pid (VARCHAR(100))(NOT EMPTY) // TODO:GG 除非是StatusError，否则Null不插入
    // msg_id (VARCHAR(300)) -> msg_id (VARCHAR(100))(NOT EMPTY)
    // ??? -> device_id (VARCHAR(200))(const="")
    // ??? -> queue_id (BIGINT)(const=0)
    // sender (VARCHAR(200)) -> sender (VARCHAR(100))(NOT EMPTY)
    // target_id/(group_id/topic/receiver) (VARCHAR(200)) -> target_id (VARCHAR(100))(NOT EMPTY)
    // 根据group_id/topic/receiver判断 -> target_type (INT)(NOT EMPTY)
    // is_outbound (BOOLEAN DEFAULT 0) -> is_outbound (BOOLEAN DEFAULT 0)(NOT EMPTY)
    // status (INT) -> status (INT)(NOT EMPTY) // TODO:GG 注意转换。所有的success，都先改成receipt，有sendAt过滤？?
    // send_at (BIGINT) -> send_at (BIGINT)(NOT EMPTY)
    // receive_at (BIGINT) -> receive_at (BIGINT) // TODO:GG 收到的就NOT EMPTY
    // is_delete (BOOLEAN DEFAULT 0) -> is_delete (BOOLEAN DEFAULT 0)(NOT EMPTY) // TODO:GG 是1的话，如果>receipt，就真删除
    // delete_at (BIGINT) -> delete_at (BIGINT) // TODO:GG deleteAt到期的话，如果>receipt，就真删除
    // type (VARCHAR(30)) -> type (VARCHAR(30))(NOT EMPTY) // TODO:GG 注意转换
    // content (TEXT) -> content (TEXT) // TODO:GG 分type，来过滤错误的格式
    // options (TEXT) -> options (TEXT)(NOT NULL) // TODO:GG 注意转换
    // ??? -> data (TEXT) ----> clear。旧的没有值
    ///----------------------
    // 消息删除的时候，根据receiveAt，来判断是否插入 (???) -> .data[receivedMessages] (Map<String, int>)
    // TODO:GG 仔细看看

    upgradeTipSink?.add(". (7/9)");

    // TODO:GG db
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
    // un_read_count (INT) -> un_read_count (INT)(NOT NULL)
    // ??? -> data (TEXT)(NOT NULL) ----> reset。只有一个senderName，直接从last_message_options里找contact然后赋值

    upgradeTipSink?.add(". (9/9)");

    // TODO:GG db
  }

  static Future deletesOldTables(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // TODO:GG db
  }
}
