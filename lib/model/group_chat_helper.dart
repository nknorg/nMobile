/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/components/dialog/dialog.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

/// @author Wei.Chou
/// @version 1.0, 24/04/2020
class GroupChatPublicChannel {
  static LOG _log = LOG('GroupChatPublicChannel'.tag());

  static Map<String, bool> _topicIsLoading = {};

  static Future<int> pullSubscribersPublicChannel(
      {NknClientProxy client, String topicName, String myChatId, SubscriberRepo repoSub, TopicRepo repoTopic, ChannelMembersBloc membersBloc}) async {
    if (_topicIsLoading.containsKey(topicName) && _topicIsLoading[topicName]) return -1;
    _topicIsLoading[topicName] = true;

    try {
      bool containsMyChatId(List<String> chatIds) {
        return myChatId != null ? chatIds.contains(myChatId) : true;
      }

      bool isMyChatId(String chatId) {
        if (myChatId != null) {
          // Only my chatId's `expiresAt` makes sense.
          if (chatId.endsWith(myChatId)) {
            _log.d("pullSubscribers | isMyChatId($myChatId): true");
            return true;
          }
        }
        return false;
      }

      final topicHashed = genTopicHash(topicName);
      final List<Subscriber> oldSubscribers = await repoSub.getByTopic(topicName);
      final chatIdsCurrentlySubscribed = List<String>();
      final Map<String, dynamic> subscribersMap = await client.getSubscribers(topicHash: topicHashed, offset: 0, limit: 10000, meta: false, txPool: true);
      chatIdsCurrentlySubscribed.addAll(subscribersMap.keys);
      if (!containsMyChatId(chatIdsCurrentlySubscribed)) {
        _log.w("pullSubscribers | not contains my chatId, delete all. myChatId: $myChatId");
        await repoSub.deleteAll(topicName);
        await repoTopic.delete(topicName);
        //repoBlackL.delete(topicName);
        membersBloc.add(MembersCount(topicName, -1, true));

        _topicIsLoading[topicName] = false;
        return -1;
      }
      _log.d("pullSubscribers | old subscribers: $oldSubscribers");
      oldSubscribers /*.clone() TODO*/ .removeWhere((el) => chatIdsCurrentlySubscribed.contains(el.chatId) || (isMyChatId(el.chatId) && !el.subscribed));
      _log.d("pullSubscribers | old subscribers filtered: $oldSubscribers");
      for (var it in oldSubscribers) {
        await repoSub.delete(topicName, it.chatId);
      }

      var count = 0;
      for (final chatId in subscribersMap.keys) {
        ++count;
        _log.d("pullSubscribers | forEach: $count");
        if (isMyChatId(chatId) /*load expiresAt*/) {
          List<dynamic> pair;
          try {
            final Map<String, dynamic> subscription = await client.getSubscription(topicHash: topicHashed, subscriber: chatId);
            _log.i("pullSubscribers | subscription: $subscription");
            pair = [subscription['meta'], subscription['expiresAt']];
          } catch (e) {
            _log.e("pullSubscribers | subscription. e:", e);
          }
          if (pair == null) {
            //if (!isMyChatId(chatId))
            await repoSub.insertOrIgnore(Subscriber(
                id: 0,
                topic: topicName,
                chatId: chatId,
                indexPermiPage: -1,
                timeCreate: DateTime.now().millisecondsSinceEpoch,
                blockHeightExpireAt: -1,
                uploaded: true,
                subscribed: true,
                uploadDone: true));
          } else {
            await repoSub.insertOrUpdate(Subscriber(
                id: 0,
                topic: topicName,
                chatId: chatId,
                indexPermiPage: -1,
                timeCreate: DateTime.now().millisecondsSinceEpoch,
                blockHeightExpireAt: pair[1] as int,
                uploaded: true,
                subscribed: true,
                uploadDone: true));
          }
          // Very slow, can't wait until the last time.
          membersBloc.add(MembersCount(topicName, count, false));
        } else {
          await repoSub.insertOrIgnore(Subscriber(
              id: 0,
              topic: topicName,
              chatId: chatId,
              indexPermiPage: -1,
              timeCreate: DateTime.now().millisecondsSinceEpoch,
              uploaded: true,
              subscribed: true,
              uploadDone: true));
        }
      }
      if (subscribersMap.isNotEmpty) {
        await repoTopic.updateSubscribersCount(topicName, subscribersMap.length);
        membersBloc.add(MembersCount(topicName, subscribersMap.length, true));
        _log.i("pullSubscribers | update topic size: ${subscribersMap.length}");
      }
      _topicIsLoading[topicName] = false;
      return subscribersMap.length;
    } catch (e) {
      _topicIsLoading[topicName] = false;
      _log.e("pullSubscribers, e:", e);
      return -1;
    }
  }
}

class GroupChatHelper {
  static Future<void> subscribeTopic({DChatAccount account, String topicName, ChatBloc chatBloc, void callback(bool success, dynamic error)}) async {
    try {
      print('GroupChatHelper create topic11'+topicName.toString());
      final hash = await account.client.subscribe(topicHash: genTopicHash(topicName));
      if (nonEmpty(hash) && hash.length >= 32) {
        // TODO: Theme.genThemeId(topicNameAdjusted),
        final themeId = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
        await TopicRepo(account.dbHolder.db).insertOrUpdateTime(Topic(
          id: 0,
          topic: topicName,
          numSubscribers: 0,
          avatarUri: null,
          themeId: themeId,
          timeUpdate: DateTime.now().millisecondsSinceEpoch,
          options: OptionsSchema.random(themeId: themeId).toJson(),
        ));
        // TODO: to be improved.
        var sendMsg = MessageSchema.fromSendData(
          from: account.client.myChatId,
          topic: topicName,
          contentType: ContentType.eventSubscribe,
        );
        sendMsg.isOutbound = true;
        sendMsg.content = sendMsg.toEventSubscribeData();
        chatBloc.add(SendMessage(sendMsg));
        callback(true, null);
        showToast('success');
      } else {
        callback(false, null);
      }
    } catch (e) {
      callback(false, e);
    }
  }

  static Future<void> unsubscribeTopic({DChatAccount account, String topicName, ChatBloc chatBloc, void callback(bool success, dynamic error)}) async {
    try {
      final hash = await account.client.unsubscribe(topicHash: genTopicHash(topicName));
      if (nonEmpty(hash) && hash.length >= 32) {
        await TopicRepo(account.dbHolder.db).delete(topicName);
//        getRepoMessage()!!.deleteAllMessagesByTopic(topicNameAdjusted)
        // delete after message sent.
//        await SubscriberRepo(account.dbHolder.db).deleteAll(topicName);
//        await BlackListRepo(account.dbHolder.db).deleteAll(topicName);
        // TODO: to be improved.
        var sendMsg = MessageSchema.fromSendData(
          from: account.client.myChatId,
          topic: topicName,
          contentType: ContentType.eventUnsubscribe,
        );
        sendMsg.isOutbound = true;
        sendMsg.content = sendMsg.toEventSubscribeData();
        chatBloc.add(SendMessage(sendMsg));
        callback(true, null);
      } else {
        callback(false, null);
      }
    } catch (e) {
      callback(false, e);
    }
  }

  static Future<void> moveSubscriberToBlackList({
    DChatAccount account,
    Topic topic,
    String chatId,
    double minerFee = 0,
    void callback(),
  }) async {
    if (topic.isPrivate && topic.isOwner(account.client.pubkey)) {
      _timer4UploadAction?.cancel();
      _timer4UploadAction = null;
      final repoSub = SubscriberRepo(account.dbHolder.db);
      final repoBlack = BlackListRepo(account.dbHolder.db);
      final sub = await repoSub.getByTopicAndChatId(topic.topic, chatId);
      if (sub?.subscribed ?? false) {
        await repoBlack.insertOrIgnore(BlackList(
          id: 0,
          topic: topic.topic,
          chatIdOrPubkey: chatId,
          indexPermiPage: sub?.indexPermiPage ?? -1,
          uploaded: false,
          subscribed: sub?.subscribed ?? false,
        ));
      } else {
        await repoBlack.delete(topic.topic, chatId);
      }
      await repoSub.delete(topic.topic, chatId);
      // TODO: to be improved.
      // sendChannelEvent(topic, helper.topicNameHash(topic), ContentType("event:add-permission"))
      _timer4UploadAction = Timer(Duration(seconds: 15), () async {
        GroupChatPrivateChannel.uploadPermissionMeta(
          client: account.client,
          topicName: topic.topic,
          minerFee: minerFee,
          accountPubkey: account.client.pubkey,
          repoSub: repoSub,
          repoBlackL: repoBlack,
        );
      });
      callback();
    }
  }

  static Future<void> moveSubscriberToWhiteList({
    DChatAccount account,
    Topic topic,
    String chatId,
    double minerFee = 0,
    void callback(),
  }) async {
    if (topic.isPrivate && topic.isOwner(account.client.pubkey)) {
      _timer4UploadAction?.cancel();
      _timer4UploadAction = null;
      final repoSub = SubscriberRepo(account.dbHolder.db);
      final repoBlack = BlackListRepo(account.dbHolder.db);
      final sub = await repoBlack.getByTopicAndChatId(topic.topic, chatId);
      await repoSub.insertOrIgnore(Subscriber(
        id: 0,
        topic: topic.topic,
        chatId: chatId,
        indexPermiPage: sub?.indexPermiPage ?? -1,
        timeCreate: DateTime.now().millisecondsSinceEpoch,
        uploaded: false,
        subscribed: sub?.subscribed ?? false,
        uploadDone: false,
      ));
      await repoBlack.delete(topic.topic, chatId);
      // TODO: to be improved.
      // sendChannelEvent(topic, helper.topicNameHash(topic), ContentType("event:remove-permission"))
      _timer4UploadAction = Timer(Duration(seconds: 15), () async {
        GroupChatPrivateChannel.uploadPermissionMeta(
          client: account.client,
          topicName: topic.topic,
          minerFee: minerFee,
          accountPubkey: account.client.pubkey,
          repoSub: repoSub,
          repoBlackL: repoBlack,
        );
      });
      callback();
    }
  }

  static Timer _timer4UploadAction;
}

final SEED_PATTERN = RegExp("[0-9A-Fa-f]{64}");
final PUBKEY_PATTERN = SEED_PATTERN;

bool isValidPubkey(String pubkey) {
  return PUBKEY_PATTERN.hasMatch(pubkey);
}

String getPubkeyFromTopicOrChatId(String s) {
  final i = s.lastIndexOf('.');
  final pubkey = i > 0 ? s.substring(i + 1) : s;
  return isValidPubkey(pubkey) ? pubkey : null;
}

bool ownerIsMeFunc(String topic, String myPubkey) => getPubkeyFromTopicOrChatId(topic) == myPubkey;

class GroupChatPrivateChannel {
  static LOG _log = LOG('GroupChatPrivateChannel'.tag());
  static Map<String, bool> _topicIsLoading = {};
  static Map<String, bool> _topicIsUploading = {};

  static Future<void> uploadPermissionMeta(
      {NknClientProxy client, String topicName, double minerFee = 0, String accountPubkey, SubscriberRepo repoSub, BlackListRepo repoBlackL}) async {
    if (_topicIsUploading.containsKey(topicName) && _topicIsUploading[topicName]) return;
    _topicIsUploading[topicName] = true;

    _log.i("uploadPermissionMeta | topicName: $topicName, minerFee: $minerFee");
    try {
      assert(ownerIsMeFunc(topicName, accountPubkey));
      final accept = "accept";
      final reject = "reject";
      final addr = "addr";
      final pubkey = "pubkey";

      bool isPubkey(String chatId) => isValidPubkey(chatId);
      Map<String, dynamic> makePrmJson(List<Subscriber> paged, List<BlackList> pagedBlack) {
        try {
          Map<String, dynamic> json = {};
          var first = true;
          paged.forEach((subs) {
            if (first) {
              final arr = [];
              // isPubkey(chatId)
              arr.add({addr: subs.chatId});
              json[accept] = arr;
              first = false;
            } else {
              (json[accept] as List).add({addr: subs.chatId});
            }
          });
          first = true;
          pagedBlack.forEach((subs) {
            if (first) {
              final arr = [];
              arr.add({(/*isPubkey(subs.chatIdOrPubkey) ? pubkey :*/ addr): subs.chatIdOrPubkey});
              json[reject] = arr;
              first = false;
            } else {
              (json[reject] as List).add({(/*isPubkey(subs.chatIdOrPubkey) ? pubkey :*/ addr): subs.chatIdOrPubkey});
            }
          });
          return json;
        } catch (e) {
          _log.e("uploadPermissionMeta | makePrmJson. e:", e);
          return null;
        }
      }

      final topicHashed = genTopicHash(topicName);
      upload(int pageIndex, String jsonOfPermission) async {
        try {
          await client.subscribe(
            identifier: "__${pageIndex}__.__permission__",
            topicHash: topicHashed,
            duration: 400000,
            fee: minerFee.toString(),
            meta: jsonOfPermission,
          );
          await repoSub.updatePageUploaded(topicName, pageIndex);
          await repoBlackL.updatePageUploaded(topicName, pageIndex);
        } catch (e) {
          _log.e("uploadPermissionMeta | upload. e:", e);
          // Don't do this, check other places and make improvements.
          /*final msgVerifyBlock = "[VerifyTransactionWithBlock]"
          if (e.message?.contains(msgVerifyBlock) == true
              || e.localizedMessage?.contains(msgVerifyBlock) == true
          ) {
              repoSub.updatePageUploaded(topicName, pageIndex)
              repoBlackL.updatePageUploaded(topicName, pageIndex)
          }*/
        }
      }

      final whiteList = await repoSub.getByTopicExceptNone(topicName);
      final blackList = await repoBlackL.getByTopic(topicName);
      var _pageIndex = -1;
      for (var el in whiteList) {
        if (el.indexPermiPage > _pageIndex) {
          _pageIndex = el.indexPermiPage;
        }
      }
      for (var el in blackList) {
        if (el.indexPermiPage > _pageIndex) {
          _pageIndex = el.indexPermiPage;
        }
      }
      final maxPageIndex = _pageIndex;
      if (maxPageIndex < 0) {
        _log.w("uploadPermissionMeta | [--, $maxPageIndex] whiteList:\n${whiteList.length}");
      }
      var pageIndex = 0;
      while (pageIndex < maxPageIndex) {
        final paged = List.of(whiteList);
        paged.retainWhere((el) => el.indexPermiPage == pageIndex);
        final pagedBlack = List.of(blackList);
        pagedBlack.retainWhere((el) => el.indexPermiPage == pageIndex);
        if (paged.any((e) => !e.uploaded) || pagedBlack.any((e) => !e.uploaded)) {
          final json = makePrmJson(paged, pagedBlack);
          if (json != null) {
            _log.d("uploadPermissionMeta | [$pageIndex, $maxPageIndex] json:\n" + JsonEncoder.withIndent('\n..|').convert(json));
            await upload(pageIndex, jsonEncode(json));
          }
        }
        ++pageIndex;
      }
      final maxSize = 1024 * 1024 * 3 / 4;
      List<Subscriber> newAdded = List.of(whiteList, growable: true);
      newAdded.retainWhere((el) => el.indexPermiPage < 0);
      // ```kotlin
      // newAdded.addAll(whiteList.filter { it.indexPermissionPage == maxPageIndex }.filterNot { s ->
      //     newAdded.any { s.chatId == it.chatId }
      // });
      // ```
      var temp = List.of(whiteList);
      temp.retainWhere((el) => el.indexPermiPage == maxPageIndex);
      temp.removeWhere((s) => newAdded.any((it) => s.chatId == it.chatId));
      newAdded.addAll(temp);

      List<BlackList> newAddedBlack = List.of(blackList, growable: true);
      newAddedBlack.retainWhere((el) => el.indexPermiPage < 0);
      // ```kotlin
      // newAddedBlack.addAll(blackList.filter { it.indexPermissionPage == maxPageIndex }.filterNot { s ->
      //     newAddedBlack.any { s.chatId == it.chatId }
      // });
      // ```
      var temp1 = List.of(blackList);
      temp1.retainWhere((el) => el.indexPermiPage == maxPageIndex);
      temp1.removeWhere((s) => newAddedBlack.any((it) => s.chatIdOrPubkey == it.chatIdOrPubkey));
      newAddedBlack.addAll(temp1);

      List<Subscriber> left = [];
      List<BlackList> leftBlack = [];
      while (newAdded.any((e) => !e.uploaded) || newAddedBlack.any((e) => !e.uploaded)) {
        final json = makePrmJson(newAdded, newAddedBlack);
        if (json == null) {
          break;
        } else {
          final jsonOfPrm = jsonEncode(json);
          final sizeBytes = utf8.encode(jsonOfPrm).length;
          if (sizeBytes > maxSize) {
            _log.w("uploadPermissionMeta | size: ${sizeBytes.toDouble() / 1024 / 1024}MB, json:\n" + JsonEncoder.withIndent('\n..|').convert(json));
            if (newAdded.isNotEmpty) {
              left.add(newAdded[newAdded.length - 1]);
              newAdded = newAdded.sublist(0, newAdded.length - 1);
            }
            if (newAddedBlack.isNotEmpty) {
              leftBlack.add(newAddedBlack[newAddedBlack.length - 1]);
              newAddedBlack = newAddedBlack.sublist(0, newAddedBlack.length - 1);
            }
          } else {
            _log.d("uploadPermissionMeta | [$pageIndex, $maxPageIndex] json:\n" + json.toString());
            for (var it in newAdded) {
              await repoSub.updatePermiPageIndex(topicName, it.chatId, pageIndex);
            }
            for (var it in newAddedBlack) {
              await repoBlackL.updatePermiPageIndex(topicName, it.chatIdOrPubkey, pageIndex);
            }
            await upload(pageIndex, jsonOfPrm);
            ++pageIndex;
            newAdded = left;
            newAddedBlack = leftBlack;
            left = [];
            leftBlack = [];
          }
        }
      }
      _log.d("uploadPermissionMeta | [--, $maxPageIndex] All Done.");

      // TODO:
      //ContentType.TopicPermisAdd
      //ContentType.TopicPrmRemove
      _topicIsUploading[topicName] = false;
    } catch (e) {
      _topicIsUploading[topicName] = false;
      _log.e("uploadPermissionMeta, e:", e);
    }
  }

  static Future<int> pullSubscribersPrivateChannel(
      {NknClientProxy client,
      String topicName,
      String accountPubkey,
      String myChatId,
      SubscriberRepo repoSub,
      BlackListRepo repoBlackL,
      TopicRepo repoTopic,
      ChannelMembersBloc membersBloc,
      void needUploadMetaCallback(String topicName)}) async {
    if (_topicIsLoading.containsKey(topicName) && _topicIsLoading[topicName]) return -1;
    _topicIsLoading[topicName] = true;
    _log.i("pullSubscribersPrivateChannel | private channel: $topicName");

    try {
      var pageIndex = 0;
      var acceptAll = false;
      final owner = getPubkeyFromTopicOrChatId(topicName);
      final topicHashed = genTopicHash(topicName);
      final whiteListChatId = Map<String, int>();
      final whiteListPubkey = Map<String, int>();
      final blackListChatId = Map<String, int>();
      final blackListPubkey = Map<String, int>();

      /// 1. Retrieve the permission control list of `a private group` page by page.
      label:
      while (true) {
        _log.i("pullSubscribersPrivateChannel | retrieve permission: __${pageIndex}__.__permission__.$owner");
        final Map<String, dynamic> subscription = await client.getSubscription(
          topicHash: topicHashed,
          subscriber: "__${pageIndex}__.__permission__.$owner",
        );
        final meta = subscription['meta'] as String;
        _log.i("pullSubscribersPrivateChannel | permission meta: $meta");
        if (meta == null || meta.trim().isEmpty) break;
        try {
          final addr = "addr";
          final pubkey = "pubkey";
          final json = jsonDecode(meta);
          final List accept = json["accept"];
          final List reject = json["reject"];
          if (accept != null) {
            for (var i = 0; i < accept.length; i++) {
              if (accept[i] == "*") {
                acceptAll = true;
                break label;
              } else {
                // type '_InternalLinkedHashMap<String, dynamic>' is not a subtype of type 'Map<String, String>'
                final /*Map<String, String>*/ item = accept[i];
                if (item.containsKey(addr)) {
                  whiteListChatId[item[addr]] = pageIndex;
                } else if (item.containsKey(pubkey)) {
                  whiteListPubkey[item[pubkey]] = pageIndex;
                }
              }
            }
          }
          if (reject != null) {
            for (var i = 0; i < reject.length; i++) {
              // type '_InternalLinkedHashMap<String, dynamic>' is not a subtype of type 'Map<String, String>'
              final /*Map<String, String>*/ item = reject[i];
              if (item.containsKey(addr)) {
                blackListChatId[item[addr]] = pageIndex;
              } else if (item.containsKey(pubkey)) {
                blackListPubkey[item[pubkey]] = pageIndex;
              }
            }
          }
        } catch (e) {
          _log.e("pullSubscribersPrivateChannel, e:", e);
        }
        ++pageIndex;
      }

      bool inBlackListFunc(String chatId) {
        return blackListChatId.containsKey(chatId) || blackListPubkey.keys.any((k) => chatId.endsWith(k));
      }

      bool notInBlackList(String chatId) => !inBlackListFunc(chatId);

      bool inWhiteListFunc(String chatId) {
        return whiteListChatId.containsKey(chatId) || whiteListPubkey.keys.any((k) => chatId.endsWith(k));
      }

      int getPageIndex(String chatId, int defalt) {
        if (whiteListChatId.containsKey(chatId)) {
          return whiteListChatId[chatId];
        } else if (blackListChatId.containsKey(chatId)) {
          return blackListChatId[chatId];
        } else {
          final list = <int>[];
          whiteListPubkey.forEach((k, v) {
            if (chatId.endsWith(k)) list.add(v);
          });
          if (list.isNotEmpty)
            return list[0];
          else {
            list.clear();
            blackListPubkey.forEach((k, v) {
              if (chatId.endsWith(k)) list.add(v);
            });
            if (list.isNotEmpty)
              return list[0];
            else
              return defalt;
          }
        }
      }

      /// 2. If I am the group owner, update the expired block height of the group.
      final ownerIsMe = ownerIsMeFunc(topicName, accountPubkey);
      if (ownerIsMe) {
        try {
          final Map<String, dynamic> subscription = await client.getSubscription(topicHash: topicHashed, subscriber: myChatId);
          _log.i("pullSubscribersPrivateChannel | updateOwnerExpireBlockHeight. $subscription");
          await repoTopic.updateOwnerExpireBlockHeight(topicName, subscription['expiresAt']);
        } catch (e) {
          _log.e("pullSubscribersPrivateChannel | updateOwnerExpireBlockHeight. e:", e);
        }
      }
      var needUploadMeta = false;
      final List<String> chatIdsCurrentlySubscribed = [];

      /// 3. Save the subscribers of this group into the `Black/White List` data table.
      final Map<String, dynamic> subscribersMap = await client.getSubscribers(topicHash: topicHashed, offset: 0, limit: 10000, meta: false, txPool: true);
      chatIdsCurrentlySubscribed.addAll(subscribersMap.keys);
      for (var chatId in subscribersMap.keys) {
        _log.i("pullSubscribersPrivateChannel | forEach: $chatId");
        final inWhiteList = inWhiteListFunc(chatId);
        final isPrmCtl = chatId.contains("__permission__");
        if (!isPrmCtl && (acceptAll || (notInBlackList(chatId) && (inWhiteList || ownerIsMe)))) {
          if (!acceptAll && !inWhiteList) {
            _log.d("pullSubscribersPrivateChannel | ownerIsMe: $chatId");
            // this case indicates `ownerIsMe`
            final subscriber = await repoSub.getByTopicAndChatId(topicName, chatId);
            if (subscriber == null) {
              _log.d("pullSubscribersPrivateChannel | insertOrUpdateOwnerIsMe($chatId)");
              needUploadMeta = true;
              await repoSub.insertOrUpdateOwnerIsMe(Subscriber(
                  id: 0,
                  topic: topicName,
                  chatId: chatId,
                  indexPermiPage: getPageIndex(chatId, -1),
                  timeCreate: DateTime.now().millisecondsSinceEpoch,
                  uploaded: false,
                  subscribed: true
                  // since this case is subscribers.
                  ,
                  uploadDone: false));
            }
          } else {
            _log.i("pullSubscribersPrivateChannel | insertOrUpdate($chatId)");
            await repoSub.insertOrUpdate(Subscriber(
                id: 0,
                topic: topicName,
                chatId: chatId,
                indexPermiPage: getPageIndex(chatId, -1),
                timeCreate: DateTime.now().millisecondsSinceEpoch,
                uploaded: true,
                subscribed: true
                // since this case is subscribers.
                ,
                uploadDone: true));
          }
        }
      }

      /// 3.1. Save the pubkey (broader scope: including chatId) in the permission-controlled
      /// blacklist into the blacklist data table.
      for (var pubkey in blackListPubkey.keys) {
        final pageIndex = blackListPubkey[pubkey];
        _log.d("pullSubscribersPrivateChannel | blacklist | pubkey: $pubkey, pageIndex: $pageIndex");
        await repoBlackL.insertOrUpdate(BlackList(
            id: 0,
            topic: topicName,
            chatIdOrPubkey: pubkey,
            indexPermiPage: pageIndex,
            uploaded: true,
            subscribed: chatIdsCurrentlySubscribed.any((e) => e.endsWith(pubkey))));
      }

      /// 3.2. Save the chatId (not included in the pubkey) in the permission-controlled
      /// blacklist into the blacklist data table.
      Map<String, int> temp = Map.of(blackListChatId);
      temp.removeWhere((chatId, _) => blackListPubkey.keys.any((pubkey) => chatId.endsWith(pubkey)));
      for (var chatId in temp.keys) {
        final pageIndex = temp[chatId];
        _log.d("pullSubscribersPrivateChannel | filtered blacklist | chatId: $chatId, pageIndex: $pageIndex");
        await repoBlackL.insertOrUpdate(BlackList(
            id: 0,
            topic: topicName,
            chatIdOrPubkey: chatId,
            indexPermiPage: pageIndex,
            uploaded: true,
            subscribed: chatIdsCurrentlySubscribed.contains(chatId)));
      }

      /// 3.3. Delete the cross-existing chatId and pubkey in the permission-controlled blacklist
      /// from the blacklist data table (only keep the wider pubkey).
      Map<String, int> temp1 = {};
      blackListChatId.forEach((chatId, index) {
        if (blackListPubkey.keys.any((pubkey) {
          // assert(chatId != pubkey);
          return chatId != pubkey && chatId.endsWith(pubkey);
        })) temp1[chatId] = index;
      });
      for (var chatId in temp1.keys) {
        final pageIndex = temp1[chatId];
        _log.d("pullSubscribersPrivateChannel | filtered blacklist | chatId: $chatId, pageIndex: $pageIndex");
        await repoBlackL.delete(topicName, chatId);
      }

      /// 3.4. If I am not the owner of the group, delete all those not in the permission control blacklist.
      if (!ownerIsMe) {
        final blackList = await repoBlackL.getByTopic(topicName);
        blackList.removeWhere((el) => inBlackListFunc(el.chatIdOrPubkey));
        for (final it in blackList) {
          await repoBlackL.delete(topicName, it.chatIdOrPubkey);
        }
      }

      /// 3.5. If I am not the owner of the group, and [not] in the subscription list or in the blacklist, delete all
      /// the whitelist (indicating that there is no one in the group),
      /// but do not delete myself from the blacklist (in order to query myself In the blacklist).
      /// And end to return.
      if (!ownerIsMe && (!chatIdsCurrentlySubscribed.contains(myChatId) || inBlackListFunc(myChatId))) {
        _log.w("pullSubscribersPrivateChannel | not contains my chatid, delete all. myChatId: $myChatId");
        await repoSub.deleteAll(topicName);
        // Channel reserved. UI need to show.
        //await repoTopic.deleteAll(topicName)
        // UI need black list to show.
        //await repoBlackL.deleteAll(topicName)
        await repoTopic.updateSubscribersCount(topicName, -1);
        membersBloc.add(MembersCount(topicName, -1, true));
        _topicIsLoading[topicName] = false;
        return -1;
      }

      /// 4. Take out all the people in the whitelist (all have been correctly written so far, but there
      /// may be redundancy and have not been deleted).
      final whiteList = await repoSub.getByTopicExceptNone(topicName);

      /// 4.1.1. If I am the owner of the group, there may be people in the whitelist who have just been invited
      /// but have not yet accepted (subscribed), so you cannot delete those who have not subscribed first.
      if (ownerIsMe) {
        /// 4.2.1. Filter out people who exist in both blacklist and whitelist.
        final blackList = await repoBlackL.getByTopic(topicName);
        final beMixed = <Subscriber>[];
        whiteList.forEach((w) {
          if (blackList.any((b) => w.chatId == b.chatIdOrPubkey || w.chatId.endsWith(b.chatIdOrPubkey))) {
            beMixed.add(w);
          }
        });

        /// 4.3.1. In extreme cases: chatIds both in whitelist and blacklist. Then you need to upload afresh.
        if (beMixed.isNotEmpty) needUploadMeta = true;

        /// 4.4.1. Delete from the blacklist the ones that exist in the whitelist but have not been uploaded
        /// successfully (maybe you just moved from the blacklist to the whitelist in the UI, but now the pull-down
        /// is triggered, the previous steps are written to the blacklist again, so simultaneously exist).
        final temp = List.of(beMixed);
        temp.removeWhere((el) => el.uploadDone);
        for (var it in temp) {
          _log.d("pullSubscribersPrivateChannel | deleteBlackList(${it.chatId})");
          await repoBlackL.delete(topicName, it.chatId);
          final pubkey = getPubkeyFromTopicOrChatId(it.chatId);
          if (pubkey != it.chatId) {
            await repoBlackL.delete(topicName, pubkey);
          }
        }

        /// 4.5.1. Delete the uploaded successfully from the whitelist (keep it in the blacklist).
        final temp1 = List.of(beMixed);
        temp1.retainWhere((el) => el.uploadDone);
        for (var it in temp1) {
          _log.w("pullSubscribersPrivateChannel | deleteWhiteList(${it.chatId})");
          await repoSub.delete(topicName, it.chatId);
        }

        /// 4.6.1. Finally, you cannot delete people who do not have a subscription (see 4.1.1).
      } else {
        /// 4.1.2. Only if I am not the owner of the group, can I delete people who have not subscribed first.
        final temp = List.of(whiteList);
        temp.removeWhere((it) => chatIdsCurrentlySubscribed.contains(it.chatId));
        for (var it in temp) {
          await repoSub.delete(topicName, it.chatId);
        }

        /// 4.1.2. Remove people who are not in the whitelist from the whitelist.
        final temp1 = List.of(whiteList);
        temp1.removeWhere((it) => inWhiteListFunc(it.chatId));
        for (var it in temp1) {
          await repoSub.delete(topicName, it.chatId);
        }

        /// 4.1.2. Remove the people in the blacklist from the whitelist.
        final temp2 = List.of(whiteList);
        temp2.retainWhere((it) => inBlackListFunc(it.chatId));
        for (var it in temp2) {
          await repoSub.delete(topicName, it.chatId);
        }
      }
      // repoSub.delete(topicName, it.chatId) not affect count,
      // but if the owner unsubscribed, he also in the white list,
      // this may cause `subscriber size < white list size`.
      final count = await repoSub.getCountOfTopic(topicName);
      await repoTopic.updateSubscribersCount(topicName, count);
      membersBloc.add(MembersCount(topicName, count, true));
      if (ownerIsMe && needUploadMeta) {
        needUploadMetaCallback(topicName);
      }
      _topicIsLoading[topicName] = false;
      return count;
    } catch (e) {
      _topicIsLoading[topicName] = false;
      _log.e("pullSubscribersPrivateChannel, e:", e);
      return -1;
    }
  }
}
