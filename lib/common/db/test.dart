import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/device_info.dart';
import 'package:nmobile/schema/message.dart';
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
import 'package:nmobile/utils/utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future addTestData(
  Database db, {
  String? selfAddress,
  String? sideAddress,
  String? topicName,
  int contactCount = 10 * 1000,
  int topicCount = 1 * 1000,
  int subscribersPerTopicMaxCount = 1 * 1000,
  int messageCount = 1 * 1000 * 1000,
  int messagePerContactMexCount = 10 * 1000,
  int messagePerTopicMexCount = 100 * 1000,
}) async {
  List<Map<String, dynamic>>? res = await db.query(
    ContactStorage.tableName,
    columns: ['*'],
    where: 'address = ?',
    whereArgs: [sideAddress],
  );
  if (res != null && res.length > 0) {
    logger.i("DB - _addTestData - success - duplicated");
    return;
  }

  Loading.show(text: "add test data progress");
  // List<Future> futures = [];
  // final batch = db.batch();

  List<String> clientAddressList = [];
  for (var i = 0; i < contactCount; i++) {
    if ((i == 0) && (selfAddress?.isNotEmpty == true)) {
      clientAddressList.add(selfAddress!);
    } else if ((i == 1) && (sideAddress?.isNotEmpty == true)) {
      clientAddressList.add(sideAddress!);
    } else {
      clientAddressList.add(Uuid().v4());
    }
  }

  // topic == topic_name
  List<String> topicNameList = [];
  for (var i = 0; i < topicCount; i++) {
    if ((i == 0) && (topicName?.isNotEmpty == true)) {
      topicNameList.add(topicName!);
    } else {
      topicNameList.add(Uuid().v4());
    }
  }

  // contact
  ContactSchema _contact = ContactSchema(
    clientAddress: clientAddressList[0],
    type: ContactType.stranger,
    createAt: DateTime.now().millisecondsSinceEpoch,
    updateAt: DateTime.now().millisecondsSinceEpoch + 1,
    firstName: Uuid().v4().substring(0, 5),
    lastName: Uuid().v4().substring(0, 5),
    profileVersion: Uuid().v4(),
    profileUpdateAt: DateTime.now().millisecondsSinceEpoch + 2,
    isTop: (0 % 2 == 0) ? true : false,
    deviceToken: Uuid().v4(),
  );
  Map<String, dynamic> entity1 = await _contact.toMap();
  logger.i("DB - _addTestData - contact start - eg:$entity1");
  // final batch1 = db.batch();
  for (var i = 0; i < (contactCount - 1); i++) {
    entity1['address'] = clientAddressList[i + 1];
    entity1['type'] = (i % 2 == 0) ? ContactType.stranger : ContactType.friend;
    entity1['create_at'] = entity1['create_at'] + 1;
    entity1['update_at'] = entity1['update_at'] + 1;
    entity1['first_name'] = entity1['address'].substring(0, 5);
    entity1['last_name'] = entity1['address'].substring(5, 10);
    entity1['profile_version'] = Uuid().v4();
    entity1['profile_expires_at'] = entity1['profile_expires_at'] + 1;
    entity1['is_top'] = (i % 2 == 0) ? 1 : 0;
    entity1['device_token'] = Uuid().v4();
    final id = await db.insert(ContactStorage.tableName, entity1);
    logger.i("DB - _addTestData - contact added - i:$i - id:$id");
    // futures.add(db.insert(ContactStorage.tableName, entity1));
    // batch1.insert(ContactStorage.tableName, entity1);
  }
  logger.i("DB - _addTestData - contact end - count:${contactCount - 1}");
  // await Future.wait(futures);
  // futures.clear();
  // final result1 = await batch1.commit(noResult: false, continueOnError: false);
  // logger.i("DB - _addTestData - contact end - count:$contactCount- success:${result1.length}");

  // deviceInfo
  DeviceInfoSchema _deviceInfo = DeviceInfoSchema(
    contactAddress: '',
    createAt: DateTime.now().millisecondsSinceEpoch,
    updateAt: DateTime.now().millisecondsSinceEpoch + 1,
    deviceId: Uuid().v4(),
    data: {'appName': "", 'appVersion': "", 'platform': "", 'platformVersion': ""},
  );
  Map<String, dynamic> entity2 = _deviceInfo.toMap();
  logger.i("DB - _addTestData - deviceInfo start - eg:$entity2");
  // final batch2 = db.batch();
  for (var i = 0; i < (contactCount - 1); i++) {
    entity2['contact_address'] = clientAddressList[i + 1];
    entity2['create_at'] = entity2['create_at'] + 1;
    entity2['update_at'] = entity2['update_at'] + 1;
    entity2['device_id'] = Uuid().v4();
    entity2['data'] = jsonEncode({
      'appName': Settings.appName,
      'appVersion': Global.build,
      'platform': (i % 3 == 0) ? PlatformName.web : ((i % 3 == 1) ? PlatformName.android : PlatformName.ios),
      'platformVersion': Global.deviceVersion,
    });
    final id = await db.insert(DeviceInfoStorage.tableName, entity2);
    logger.i("DB - _addTestData - deviceInfo added - i:$i - id:$id");
    // futures.add(db.insert(DeviceInfoStorage.tableName, entity2));
    // batch2.insert(DeviceInfoStorage.tableName, entity2);
  }
  logger.i("DB - _addTestData - deviceInfo end - count:${contactCount - 1}");
  // await Future.wait(futures);
  // futures.clear();
  // final result2 = await batch2.commit(continueOnError: false);
  // logger.i("DB - _addTestData - deviceInfo end - count:$contactCount - success:${result2.length}");

  // topic
  TopicSchema _topic = TopicSchema.create(Uuid().v4())!;
  _topic.type = TopicType.privateTopic;
  _topic.createAt = DateTime.now().millisecondsSinceEpoch;
  _topic.updateAt = DateTime.now().millisecondsSinceEpoch + 1;
  _topic.joined = false;
  _topic.subscribeAt = DateTime.now().millisecondsSinceEpoch + 2;
  _topic.expireBlockHeight = DateTime.now().millisecondsSinceEpoch + 3;
  _topic.count = Random().nextInt(1000);
  _topic.isTop = (0 % 2 == 0) ? true : false;
  Map<String, dynamic> entity3 = _topic.toMap();
  logger.i("DB - _addTestData - topic start - eg:$entity3");
  // final batch3 = db.batch();
  for (var i = 0; i < topicCount; i++) {
    entity3['topic'] = topicNameList[i];
    entity3['type'] = isPrivateTopicReg(entity3['topic']) ? TopicType.privateTopic : TopicType.publicTopic;
    entity3['create_at'] = entity3['create_at'] + 1;
    entity3['update_at'] = entity3['update_at'] + 1;
    entity3['joined'] = (i % 2 == 0) ? 0 : 1;
    entity3['subscribe_at'] = entity3['subscribe_at'] + 1;
    entity3['expire_height'] = entity3['expire_height'] + 1;
    entity3['count'] = Random().nextInt(1000);
    entity3['is_top'] = (i % 2 == 0) ? 0 : 1;
    final id = await db.insert(TopicStorage.tableName, entity3);
    logger.i("DB - _addTestData - topic added - i:$i - id:$id");
    // futures.add(db.insert(TopicStorage.tableName, entity3));
    // batch3.insert(TopicStorage.tableName, entity3);
  }
  logger.i("DB - _addTestData - topic end - count:$topicCount");
  // await Future.wait(futures);
  // futures.clear();
  // final result3 = await batch3.commit(continueOnError: true);
  // logger.i("DB - _addTestData - topic end - count:$topicCount - success:${result3.length}");

  // subscriber
  SubscriberSchema _subscriber = SubscriberSchema.create(topicNameList[0], clientAddressList[0], null, null)!;
  _subscriber.createAt = DateTime.now().millisecondsSinceEpoch;
  _subscriber.updateAt = DateTime.now().millisecondsSinceEpoch + 1;
  _subscriber.status = 0;
  _subscriber.permPage = 0;
  Map<String, dynamic> entity4 = _subscriber.toMap();
  logger.i("DB - _addTestData - subscriber start - eg:$entity4");
  // final batch4 = db.batch();
  for (var i = 0; i < subscribersPerTopicMaxCount; i++) {
    entity4['topic'] = topicNameList[0];
    entity4['chat_id'] = clientAddressList[i];
    entity4['create_at'] = entity4['create_at'] + 1;
    entity4['update_at'] = entity4['update_at'] + 1;
    entity4['status'] = SubscriberStatus.Subscribed;
    entity4['perm_page'] = Random().nextInt(subscribersPerTopicMaxCount ~/ 10);
    final id = await db.insert(SubscriberStorage.tableName, entity4);
    logger.i("DB - _addTestData - subscriber added(1) - i:$i - id:$id");
    // futures.add(db.insert(SubscriberStorage.tableName, entity4));
    // batch4.insert(SubscriberStorage.tableName, entity4);
  }
  for (var i = 0; i < (contactCount - subscribersPerTopicMaxCount); i++) {
    entity4['topic'] = topicNameList[Random().nextInt(topicNameList.length - 1) + 1];
    entity4['chat_id'] = clientAddressList[subscribersPerTopicMaxCount + i];
    entity4['create_at'] = entity4['create_at'] + 1;
    entity4['update_at'] = entity4['update_at'] + 1;
    entity4['status'] = (i % 2 == 0) ? SubscriberStatus.Subscribed : ((i % 3 == 0) ? SubscriberStatus.InvitedSend : ((i % 3 == 1) ? SubscriberStatus.InvitedReceipt : SubscriberStatus.Unsubscribed));
    entity4['perm_page'] = Random().nextInt(10);
    final id = await db.insert(SubscriberStorage.tableName, entity4);
    logger.i("DB - _addTestData - subscriber added(2) - i:$i - id:$id");
    // futures.add(db.insert(SubscriberStorage.tableName, entity4));
    // batch4.insert(SubscriberStorage.tableName, entity4);
  }
  logger.i("DB - _addTestData - subscriber end - count:$contactCount");
  // await Future.wait(futures);
  // futures.clear();
  // final result4 = await batch4.commit(continueOnError: false);
  // logger.i("DB - _addTestData - subscriber end - count:$contactCount - success:${result4.length}");

  // message
  MessageSchema _message = MessageSchema(
    pid: Uint8List(128),
    msgId: Uuid().v4(),
    from: (0 % 2 == 0) ? clientAddressList[0] : clientAddressList[1],
    to: (0 % 2 == 0) ? clientAddressList[1] : clientAddressList[0],
    topic: (0 % (contactCount ~/ topicCount) == 0) ? topicNameList[0] : null,
    status: (0 % 10 == 0) ? ((0 % 2 == 0) ? ((0 % 2 == 0) ? MessageStatus.SendReceipt : MessageStatus.SendSuccess) : MessageStatus.Received) : MessageStatus.Read,
    isOutbound: (0 % 2 == 0) ? true : false,
    isDelete: (0 % 20 == 0) ? true : false,
    sendAt: DateTime.now().millisecondsSinceEpoch,
    receiveAt: DateTime.now().millisecondsSinceEpoch + 1,
    deleteAt: (0 % 20 == 0) ? DateTime.now().millisecondsSinceEpoch - 1 : null,
    contentType: (0 % 3 == 0) ? MessageContentType.textExtension : MessageContentType.text,
    content: "${0}---${Uuid().v4()}",
  );
  Map<String, dynamic> entity5 = _message.toMap();
  logger.i("DB - _addTestData - message start - eg:$entity5");
  // final batch5 = db.batch();
  for (var i = 0; i < messagePerContactMexCount; i++) {
    entity5['pid'] = hexEncode(Uint8List(128));
    entity5['msg_id'] = Uuid().v4();
    entity5['sender'] = (i % 2 == 0) ? clientAddressList[0] : clientAddressList[1];
    entity5['receiver'] = (i % 2 == 0) ? clientAddressList[1] : clientAddressList[0];
    entity5['topic'] = null;
    entity5['target_id'] = (i % 2 == 0) ? entity5['receiver'] : entity5['sender'];
    entity5['status'] = (i % 10 == 0) ? ((i % 2 == 0) ? ((i % 2 == 0) ? MessageStatus.SendReceipt : MessageStatus.SendSuccess) : MessageStatus.Received) : MessageStatus.Read;
    entity5['is_outbound'] = (i % 2 == 0) ? 1 : 0;
    entity5['is_delete'] = (i % 20 == 0) ? 1 : 0;
    entity5['send_at'] = entity5['send_at'] + 1;
    entity5['receive_at'] = entity5['receive_at'] + 1;
    entity5['delete_at'] = (i % 20 == 0) ? DateTime.now().millisecondsSinceEpoch - 1 : null;
    entity5['type'] = (i % 3 == 0) ? MessageContentType.textExtension : MessageContentType.text;
    entity5['content'] = "$i--${(i % 20 == 0) ? "deleted" : ""}--${Uuid().v4()}";
    final id = await db.insert(MessageStorage.tableName, entity5);
    logger.i("DB - _addTestData - message added(1) - i:$i - id:$id");
    // futures.add(db.insert(MessageStorage.tableName, entity5));
    // batch5.insert(MessageStorage.tableName, entity5);
  }
  for (var i = 0; i < messagePerTopicMexCount; i++) {
    entity5['pid'] = hexEncode(Uint8List(128));
    entity5['msg_id'] = Uuid().v4();
    entity5['sender'] = (i % 10 == 0) ? clientAddressList[0] : clientAddressList[Random().nextInt(clientAddressList.length - 1) + 1];
    entity5['receiver'] = null;
    entity5['topic'] = topicNameList[0];
    entity5['target_id'] = entity5['topic'];
    entity5['status'] = (i % 10 == 0) ? ((i % 2 == 0) ? ((i % 2 == 0) ? MessageStatus.SendReceipt : MessageStatus.SendSuccess) : MessageStatus.Received) : MessageStatus.Read;
    entity5['is_outbound'] = (i % 10 == 0) ? 1 : 0;
    entity5['is_delete'] = (i % 20 == 0) ? 1 : 0;
    entity5['send_at'] = entity5['send_at'] + 1;
    entity5['receive_at'] = entity5['receive_at'] + 1;
    entity5['delete_at'] = (i % 20 == 0) ? DateTime.now().millisecondsSinceEpoch - 1 : null;
    entity5['type'] = (i % 3 == 0) ? MessageContentType.textExtension : MessageContentType.text;
    entity5['content'] = "$i--${(i % 20 == 0) ? "deleted" : ""}--${Uuid().v4()}";
    final id = await db.insert(MessageStorage.tableName, entity5);
    logger.i("DB - _addTestData - message added(2) - i:$i - id:$id");
    // futures.add(db.insert(MessageStorage.tableName, entity5));
    // batch5.insert(MessageStorage.tableName, entity5);
  }
  for (var i = 0; i < (messageCount - messagePerContactMexCount - messagePerTopicMexCount); i++) {
    entity5['pid'] = hexEncode(Uint8List(128));
    entity5['msg_id'] = Uuid().v4();
    entity5['sender'] = (i % 2 == 0) ? clientAddressList[0] : clientAddressList[Random().nextInt(clientAddressList.length - 1) + 1];
    entity5['receiver'] = (i % (contactCount ~/ topicCount) != 0) ? ((i % 2 == 0) ? entity5['sender'] : clientAddressList[0]) : null;
    entity5['topic'] = (i % (contactCount ~/ topicCount) == 0) ? topicNameList[Random().nextInt(topicNameList.length - 1) + 1] : null;
    entity5['target_id'] = (entity5['topic'] != null) ? entity5['topic'] : ((i % 2 == 0) ? entity5['receiver'] : entity5['sender']);
    entity5['status'] = (i % 10 == 0) ? ((i % 2 == 0) ? ((i % 2 == 0) ? MessageStatus.SendReceipt : MessageStatus.SendSuccess) : MessageStatus.Received) : MessageStatus.Read;
    entity5['is_outbound'] = (i % 2 == 0) ? 1 : 0;
    entity5['is_delete'] = (i % 20 == 0) ? 1 : 0;
    entity5['send_at'] = entity5['send_at'] + 1;
    entity5['receive_at'] = entity5['receive_at'] + 1;
    entity5['delete_at'] = (i % 20 == 0) ? DateTime.now().millisecondsSinceEpoch - 1 : null;
    entity5['type'] = (i % 3 == 0) ? MessageContentType.textExtension : MessageContentType.text;
    entity5['content'] = "$i--${(i % 20 == 0) ? "deleted" : ""}--${Uuid().v4()}";
    final id = await db.insert(MessageStorage.tableName, entity5);
    logger.i("DB - _addTestData - message added(3) - i:$i - id:$id");
    // futures.add(db.insert(MessageStorage.tableName, entity5));
    // batch5.insert(MessageStorage.tableName, entity5);
  }
  logger.i("DB - _addTestData - message end - count:$messageCount");
  // await Future.wait(futures);
  // futures.clear();
  // final result5 = await batch5.commit(continueOnError: false);
  // logger.i("DB - _addTestData - message end - count:$messageCount - success:${result5.length}");

  // session
  SessionSchema _session = SessionSchema(
    targetId: clientAddressList[0],
    type: SessionType.CONTACT,
    lastMessageAt: DateTime.now().millisecondsSinceEpoch - Random().nextInt(100000),
    lastMessageOptions: null,
    isTop: false,
    unReadCount: 0,
  );
  Map<String, dynamic> entity6 = await _session.toMap();
  logger.i("DB - _addTestData - session start - eg:$entity6");
  // final batch6 = db.batch();
  for (var i = 0; i < (contactCount - 1); i++) {
    entity6['target_id'] = clientAddressList[i + 1];
    entity6['type'] = SessionType.CONTACT;
    entity6['last_message_at'] = DateTime.now().millisecondsSinceEpoch - Random().nextInt(100000);
    entity6['last_message_options'] = null;
    entity6['is_top'] = (i == 0) ? 1 : 0;
    entity6['un_read_count'] = Random().nextInt(10);
    final id = await db.insert(SessionStorage.tableName, entity6);
    logger.i("DB - _addTestData - session added(1) - i:$i - id:$id");
    // futures.add(db.insert(SessionStorage.tableName, entity6));
    // batch6.insert(SessionStorage.tableName, entity6);
  }
  for (var i = 0; i < topicCount; i++) {
    entity6['target_id'] = topicNameList[i];
    entity6['type'] = SessionType.TOPIC;
    entity6['last_message_at'] = DateTime.now().millisecondsSinceEpoch - Random().nextInt(100000);
    entity6['last_message_options'] = null;
    entity6['is_top'] = (i == 0) ? 1 : 0;
    entity6['un_read_count'] = Random().nextInt(100);
    final id = await db.insert(SessionStorage.tableName, entity6);
    logger.i("DB - _addTestData - session added(2) - i:$i - id:$id");
    // futures.add(db.insert(SessionStorage.tableName, entity6));
    // batch6.insert(SessionStorage.tableName, entity6);
  }
  logger.i("DB - _addTestData - session end - count:${contactCount + topicCount - 1}");
  // await Future.wait(futures);
  // futures.clear();
  // final result6 = await batch6.commit(continueOnError: false);
  // logger.i("DB - _addTestData - session end - count:${contactCount + topicCount} - success:${result6.length}");

  Loading.dismiss();
}
