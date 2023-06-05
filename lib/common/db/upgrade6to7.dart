import 'dart:async';
import 'dart:convert';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/message_piece.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/storages/subscriber.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// TODO:GG 应该就不是升级，是迁移了，版本号还是改成7？
// TODO:GG 各个表名要修改吗？
// TODO:GG 尽量不要importSchema
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
    // avatar (TEXT) -> avatar (TEXT)
    // first_name (VARCHAR(50)) -> first_name (VARCHAR(50))(NOT EMPTY)
    // last_name (VARCHAR(50)) -> last_name (VARCHAR(50))(NOT NULL)
    // .data[remarkName/firstName] (String) -> remark_name (VARCHAR(50))(NOT NULL)
    // type (INT) -> type (INT)(NOT EMPTY)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(const=0)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // data (TEXT) -> data (TEXT)(NOT NULL) ----> reset。还有notes,mappedAddress,nknWalletAddress
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
    // data (TEXT) -> data (TEXT)(NOT NULL) ---->  clear。都是临时的，直接清除掉吧
    ///----------------------
    // if (e['theme_id'] != null && (e['theme_id'] is int) && e['theme_id'] != 0) {
    // topicSchema.options?.avatarBgColor = Color(e['theme_id']);
    // }

    upgradeTipSink?.add(". (3/9)");

    // TODO:GG db
  }

  static Future upgradeSubscriber(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // topic (VARCHAR(200)) -> topic_id (VARCHAR(100))(NOT EMPTY)
    // chat_id (VARCHAR(200)) -> contact_address (VARCHAR(100))(NOT EMPTY)
    // status (INT) -> status (INT)(NOT EMPTY)
    // perm_page (INT) -> perm_page (INT)
    // data (TEXT) -> data (TEXT)(NOT NULL) ---->  clear。都是临时的，直接清除掉吧

    upgradeTipSink?.add(". (4/9)");

    // v7 table
    if (!(await DB.checkTableExists(db, SubscriberStorage.tableName))) {
      upgradeTipSink?.add(".. (4/9)");
      await SubscriberStorage.create(db);
    } else {
      logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - exist");
    }
    upgradeTipSink?.add("... (4/9)");

    // v5 table
    String oldTableName = "Subscriber_3";
    if (!(await DB.checkTableExists(db, oldTableName))) {
      logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName no exist");
      return;
    }
    upgradeTipSink?.add(".... (4/9)");

    // total
    int totalRawCount = Sqflite.firstIntValue(await db.query(oldTableName, columns: ['COUNT(id)'])) ?? 0;

    // convert all data v5 to v7
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
        Map<String, dynamic> newData = Map();
        // duplicated
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
        // insert
        Map<String, dynamic> entity = {
          'create_at': newCreateAt,
          'update_at': newUpdateAt,
          'topic_id': newTopicId,
          'contact_address': newContactAddress,
          'status': newStatus,
          'perm_page': newPermPage,
          'data': jsonEncode(newData),
        };
        int id = await db.insert(SubscriberStorage.tableName, entity);
        if (id > 0) {
          logger.d("Upgrade6to7 - ${SubscriberStorage.tableName} - insert success - data:$entity");
          total++;
        } else {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - insert fail - data:$entity");
        }
      }
      upgradeTipSink?.add("..... (4/9) ${(total * 100) ~/ (totalRawCount * 100)}%");
      // loop
      if (results.length < limit) {
        if (total != totalRawCount) {
          logger.w("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName loop over - progress:$offset/$totalRawCount");
        } else {
          logger.i("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName loop over - progress:$offset/$totalRawCount");
        }
        break;
      } else {
        logger.d("Upgrade6to7 - ${SubscriberStorage.tableName} - $oldTableName loop next - progress:$offset/$totalRawCount");
      }
    }
  }

  static Future upgradePrivateGroup(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // group_id (VARCHAR(200)) -> group_id (VARCHAR(100))(NOT EMPTY)
    // type (INT) -> type (INT)(const=0)
    // version (TEXT) -> version (TEXT)
    // name (VARCHAR(200)) -> name (VARCHAR(100))(NOT EMPTY)
    // count (INT) -> count (INT)(NOT NULL)
    // avatar (TEXT) -> avatar (TEXT)
    // joined (BOOLEAN DEFAULT 0) -> joined (BOOLEAN DEFAULT 0)(NOT NULL)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(const=0)
    // options (TEXT) -> options (TEXT)(NOT NULL)
    // data (TEXT) -> data (TEXT)(NOT NULL) ----> equal。拷贝就行
    ///----------------------
    // 消息删除的时候，根据receiveAt，来判断是否插入 (???) -> .data[receivedMessages] (Map<String, int>)

    upgradeTipSink?.add(". (5/9)");

    // TODO:GG db
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
    // data (TEXT) -> data (TEXT)(NOT NULL) ---> clear。根本没有值

    upgradeTipSink?.add(". (6/9)");

    // TODO:GG db
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
}
