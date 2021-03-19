

import 'dart:convert';

import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class GroupDataCenter{
  static String subscriberTableName = '';
  static Future<List<Subscriber>> fetchLocalGroupMembers(String topicName) async{
    Database cdb = await NKNDataManager().currentDatabase();
    List<Map<String, dynamic>> result = await cdb.query(subscriberTableName,
        where: 'topic = ?',
        whereArgs: [topicName],
        orderBy: 'time_create ASC');

    List<Subscriber> groupMembers = List<Subscriber>();
    if (result != null && result.length > 0){
      for (Map subscriber in result){
        NLog.w('Subscriber is____'+subscriber.toString());
      }
      Subscriber sub = Subscriber(

      );
      groupMembers.add(sub);
    }

    return groupMembers;
  }

  static Future<List> pullPrivateSubscribers(String topicName) async{
    int pageIndex = 0;
    final topicHashed = genTopicHash(topicName);

    final owner = getPubkeyFromTopicOrChatId(topicName);
    NLog.w('MetaData owner is___'+owner.toString());
    while (true) {
      var subscription =
      await NKNClientCaller.getSubscription(
        topicHash: topicHashed,
        subscriber: "__${pageIndex}__.__permission__.$owner",
      );

      NLog.w('MetaData is___'+subscription.toString());
      // Map subsribers = await NKNClientCaller.getSubscribers(
      //     topicHash: topicHashed,
      //     offset: 0,
      //     limit: 10000,
      //     meta: false,
      //     txPool: true);
      // NLog.w('subsribers is___'+subsribers.toString());
      //
      final meta = subscription['meta'] as String;

      if (meta == null || meta.trim().isEmpty) {
        NLog.w('meta is null');
        break;
      }
      try {
        final addr = "addr";
        final pubkey = "pubkey";
        final json = jsonDecode(meta);
        final List accept = json["accept"];
        final List reject = json["reject"];
        NLog.w('json is____'+json.toString());
        if (accept != null) {
          // for (var i = 0; i < accept.length; i++) {
          //   if (accept[i] == "*") {
          //     acceptAll = true;
          //     break label;
          //   } else {
          //     // type '_InternalLinkedHashMap<String, dynamic>' is not a subtype of type 'Map<String, String>'
          //     final /*Map<String, String>*/ item = accept[i];
          //     if (item.containsKey(addr)) {
          //       whiteListChatId[item[addr]] = pageIndex;
          //     } else if (item.containsKey(pubkey)) {
          //       whiteListPubkey[item[pubkey]] = pageIndex;
          //     }
          //   }
          // }
        }
        if (reject != null) {
          // for (var i = 0; i < reject.length; i++) {
          //   // type '_InternalLinkedHashMap<String, dynamic>' is not a subtype of type 'Map<String, String>'
          //   final /*Map<String, String>*/ item = reject[i];
          //   if (item.containsKey(addr)) {
          //     blackListChatId[item[addr]] = pageIndex;
          //   } else if (item.containsKey(pubkey)) {
          //     blackListPubkey[item[pubkey]] = pageIndex;
          //   }
          // }
        }
      } catch (e) {
        NLog.e("pullSubscribersPrivateChannel, e:" + e.toString());
      }
      ++pageIndex;
    }
  }

  static Future<List> pullSubscribersPublicChannel(String topicName) async {
    try {
      final topicHashed = genTopicHash(topicName);

      List<Subscriber> dataList = new List<Subscriber>();
      NKNClientCaller.getSubscribers(
          topicHash: topicHashed,
          offset: 0,
          limit: 10000,
          meta: false,
          txPool: true)
          .then((subscribersMap) async {
        for (String chatId in subscribersMap.keys) {
          Subscriber sub = Subscriber(
              id: 0,
              topic: topicName,
              chatId: chatId,
              indexPermiPage: -1,
              timeCreate: DateTime.now().millisecondsSinceEpoch,
              blockHeightExpireAt: -1,
              uploaded: true,
              subscribed: true,
              uploadDone: true);
          dataList.add(sub);
        }
        Subscriber selfSub = Subscriber(
            id: 0,
            topic: topicName,
            chatId: NKNClientCaller.currentChatId,
            indexPermiPage: -1,
            timeCreate: DateTime.now().millisecondsSinceEpoch,
            blockHeightExpireAt: -1,
            uploaded: true,
            subscribed: true,
            uploadDone: true);

        dataList.add(selfSub);
        if (dataList.length > 0) {
          for (int i = 0; i < dataList.length; i++) {
            Subscriber subscriber = dataList[i];
            SubscriberRepo().insertSubscriber(subscriber);
          }
          NLog.w('Insert Members___'+dataList.length.toString()+'__forTopic__'+topicName);
          return dataList.length;
        }
      });
      return dataList;
    } catch (e) {
      if (e != null) {
        NLog.w('group_chat_helper E:' + e.toString());
      }
      return null;
    }
  }
}