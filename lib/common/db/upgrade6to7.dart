import 'dart:async';

import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/session.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// TODO:GG 应该就不是升级，是迁移了，版本号还是改成7？
// TODO:GG 各个表名要修改吗？
class Upgrade6to7 {
  static Future upgradeDeviceInfo(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // contact_address (VARCHAR(200)) -> contact_address (VARCHAR(100))(NOT EMPTY)
    // device_id (TEXT) -> device_id (VARCHAR(200))(NOT EMPTY) ---> 注意如果是empty就舍弃了
    // contact.device_token (TEXT) -> device_token (TEXT)(NOT NULL) ---> 是否带有[XXX:]的前缀，不带就舍弃。 如果contact有token，那么也可以健一个device_id为empty的，把token塞进去?????
    // update_at/create_at (BIGINT) -> online_at (BIGINT)(NOT EMPTY)
    // data (TEXT) -> data (TEXT)(NOT NULL) ----> equal。旧的值直接拷贝，新的临时创建

    upgradeTipSink?.add("... (1/8)");

    // TODO:GG db
  }

  static Future upgradeContact(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
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

    upgradeTipSink?.add("... (2/8)");

    // TODO:GG db
  }

  static Future upgradeTopic(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
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

    upgradeTipSink?.add("... (3/8)");

    // TODO:GG db
  }

  static Future upgradeSubscriber(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
    // create_at (BIGINT) -> create_at (BIGINT)(NOT EMPTY)
    // update_at (BIGINT) -> update_at (BIGINT)(NOT EMPTY)
    // topic (VARCHAR(200)) -> topic_id (VARCHAR(100))(NOT EMPTY)
    // chat_id (VARCHAR(200)) -> contact_address (VARCHAR(100))(NOT EMPTY)
    // status (INT) -> status (INT)(NOT EMPTY)
    // perm_page (INT) -> perm_page (INT)
    // data (TEXT) -> data (TEXT)(NOT NULL) ---->  clear。都是临时的，直接清除掉吧

    upgradeTipSink?.add("... (4/8)");

    // TODO:GG db
  }

  static Future upgradePrivateGroup(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
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

    upgradeTipSink?.add("... (5/8)");

    // TODO:GG db
  }

  static Future upgradePrivateGroupItem(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
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

    upgradeTipSink?.add("... (6/8)");

    // TODO:GG db
  }

  static Future upgradeMessage(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
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

    upgradeTipSink?.add("... (7/8)");

    // TODO:GG db
  }

  static Future upgradeMessagePiece(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // nothing, just temp table
  }

  static Future upgradeSession(Database db, {StreamSink<String?>? upgradeTipSink}) async {
    // id (NOT NULL) -> id (NOT NULL)
    // target_id (VARCHAR(200)) -> target_id (VARCHAR(100))(NOT EMPTY)
    // type (INT) -> type (INT)(NOT EMPTY)
    // last_message_at (BIGINT) -> last_message_at (BIGINT)(NOT EMPTY)
    // last_message_options (TEXT) -> last_message_options (TEXT)
    // is_top (BOOLEAN DEFAULT 0) -> is_top (BOOLEAN DEFAULT 0)(NOT EMPTY)
    // un_read_count (INT) -> un_read_count (INT)(NOT NULL)
    // ??? -> data (TEXT)(NOT NULL) ----> reset。只有一个senderName，直接从last_message_options里找contact然后赋值

    upgradeTipSink?.add("... (8/8)");

    // TODO:GG db
  }
}
