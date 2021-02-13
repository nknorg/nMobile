/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:convert';

import 'package:nmobile/blocs/chat/channel_bloc.dart';
import 'package:nmobile/blocs/chat/channel_event.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class GroupChatPublicChannel {
  static final SubscriberRepo _subscriberRepo = SubscriberRepo();
  static final TopicRepo _topicRepo = TopicRepo();

  static Future<ContactSchema> checkContactIfExists(String clientAddress) async {
    var contact = await ContactSchema.fetchContactByAddress(clientAddress);
    if (contact == null) {
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
      if (clientAddress != null){
        NLog.w('Insert contact stranger__'+clientAddress.toString());
      }
      else{
        NLog.w('got clientAddress Wrong!!!');
      }
      if (walletAddress == null){
        NLog.w('got walletAddress Wrong!!!');
      }
      contact = ContactSchema(type: ContactType.stranger,
          clientAddress: clientAddress,
          nknWalletAddress: walletAddress);
      await contact.insertContact();
    }
    return contact;
  }

  static Future<int> pullSubscribersPublicChannel(
      {String topicName, String myChatId, ChannelBloc membersBloc}) async {
    try {
      final topicHashed = genTopicHash(topicName);

      List<Subscriber> dataList = new List<Subscriber>();
      NKNClientCaller.getSubscribers(topicHash: topicHashed, offset: 0, limit: 10000, meta: false, txPool: true).then((subscribersMap) async {
        for (String chatId in subscribersMap.keys){
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
          for (int i = 0; i < dataList.length; i++){
            Subscriber subscriber = dataList[i];
            _subscriberRepo.insertSubscriber(subscriber);
          }
          membersBloc.add(ChannelMemberCountEvent(topicName));

          return dataList.length;
        }
      });
      return 0;
    } catch (e) {
      if (e != null){
        NLog.w('group_chat_helper E:'+e.toString());
      }
      return -1;
    }
  }
}

class GroupChatHelper {

  static final SubscriberRepo _subscriberRepo = SubscriberRepo();
  static final TopicRepo _topicRepo = TopicRepo();

  static Future<List<String>> fetchGroupMembers(String topicName) async{
    List <String> memberList = await _subscriberRepo.getAllSubscriberByTopic(topicName);
    if (memberList != null && memberList.length > 0){
      if (topicName != null){
        NLog.w('Got Topic__'+topicName.toString()+'count is__'+memberList.length.toString());
      }
      return memberList;
    }
    else{
      if (topicName != null){
        NLog.w('Wrong get no group member__'+topicName);
      }
      else{
        NLog.w('Wrong!!! topic Name is null');
      }
      return null;
    }
  }

  static Future<Topic> fetchTopicInfoByName(String topicName) async{
    Topic topicInfo = await _topicRepo.getTopicByName(topicName);
    return topicInfo;
  }

  static insertTopicIfNotExists(String topicName) async{
    if (topicName != null){
      await _topicRepo.insertTopicByTopicName(topicName);
      await insertSelfSubscriber(topicName);

      NLog.w('Insert topicName __'+topicName.toString());
    }
    else{
      NLog.w('Wrong!!! insertTopicIfNotExists no topicName');
    }
  }

  static insertSelfSubscriber(String topicName) async{
    Subscriber selfSub = await _subscriberRepo.getByTopicAndChatId(topicName, NKNClientCaller.currentChatId);
    if (selfSub == null){
      selfSub = Subscriber(
          id: 0,
          topic: topicName,
          chatId: NKNClientCaller.currentChatId,
          indexPermiPage: -1,
          timeCreate: DateTime.now().millisecondsSinceEpoch,
          blockHeightExpireAt: -1,
          uploaded: true,
          subscribed: true,
          uploadDone: true
      );
    }
    await _subscriberRepo.insertSubscriber(selfSub);
  }

  static insertSubscriber(Subscriber sub) async{
    await _subscriberRepo.insertSubscriber(sub);
  }

  static Future<bool> checkMemberIsInGroup(String memberId,String topicName) async{
    Subscriber subscriber = await _subscriberRepo.getByTopicAndChatId(topicName, memberId);
    if (subscriber != null){
      return true;
    }
    else{
      return false;
    }
  }

  static Future<bool> removeTopicAndSubscriber(String topicName) async{
    await _topicRepo.delete(topicName);
    await _subscriberRepo.deleteAll(topicName);
    return true;
  }

  static Future<void> subscribeTopic({String topicName, ChatBloc chatBloc, void callback(bool success, dynamic error)}) async {
    try {
      final hash = await NKNClientCaller.subscribe(topicHash: genTopicHash(topicName));

      NLog.w('hashhash got Exception:'+hash.toString());
      if (nonEmpty(hash) && hash.length >= 32) {
        await GroupChatHelper.insertTopicIfNotExists(topicName);
        var sendMsg = MessageSchema.fromSendData(
          from: NKNClientCaller.currentChatId,
          topic: topicName,
          contentType: ContentType.eventSubscribe,
        );
        sendMsg.content = sendMsg.toEventSubscribeData();
        chatBloc.add(SendMessageEvent(sendMsg));
        callback(true, null);
        showToast('success');
      } else {
        NLog.w('callback callback Exception:'+hash.toString());
        callback(false, null);
      }
    } catch (e) {
      if (e != null){
        NLog.w('Group_Chat_Helper__ got Exception:'+e.toString());
      }
      if (e.toString().contains('duplicate subscription exist in block')){
        await GroupChatHelper.insertTopicIfNotExists(topicName);

        var sendMsg = MessageSchema.fromSendData(
          from: NKNClientCaller.currentChatId,
          topic: topicName,
          contentType: ContentType.eventSubscribe,
        );
        sendMsg.content = sendMsg.toEventSubscribeData();
        chatBloc.add(SendMessageEvent(sendMsg));
        callback(true, null);
      }
      else{
        callback(false, e);
      }
    }
  }

  static deleteTopicWithSubscriber(String topic){
    if (topic != null){
      _topicRepo.delete(topic);
      _subscriberRepo.deleteAll(topic);
    }
    else{
      NLog.w('Delete topic Wrong!!! topic is null');
    }
  }

  static Future<void> unsubscribeTopic({String topicName, ChatBloc chatBloc, void callback(bool success, dynamic error)}) async {
    try {
      final hash = await NKNClientCaller.unsubscribe(topicHash: genTopicHash(topicName));
      if (nonEmpty(hash) && hash.length >= 32) {
        await TopicRepo().delete(topicName);

        var sendMsg = MessageSchema.fromSendData(
          from: NKNClientCaller.currentChatId,
          topic: topicName,
          contentType: ContentType.eventUnsubscribe,
        );
        sendMsg.content = sendMsg.toEventSubscribeData();
        chatBloc.add(SendMessageEvent(sendMsg));
        // chatBloc.add(RefreshMessageListEvent());
        deleteTopicWithSubscriber(topicName);
        callback(true, null);
      } else {
        callback(false, null);
      }
    } catch (e) {
      if (e != null){
        NLog.w('unsubscribeTopic E:'+e.toString());
      }
      if (e.toString().contains('duplicate subscription exist in block') ||
      e.toString().contains('can not append tx to txpool')){
        deleteTopicWithSubscriber(topicName);
        callback(true, null);
        return;
      }
      callback(false, e);
    }
  }

  static Future<void> moveSubscriberToBlackList({
    Topic topic,
    String chatId,
    double minerFee = 0,
    void callback(),
  }) async {
    if (topic.isPrivate && topic.isOwner(NKNClientCaller.currentChatId)) {
      _timer4UploadAction?.cancel();
      _timer4UploadAction = null;
      final repoSub = SubscriberRepo();
      final repoBlack = BlackListRepo();
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
          topicName: topic.topic,
          minerFee: minerFee,
          accountPubkey: NKNClientCaller.currentChatId,
          repoSub: repoSub,
          repoBlackL: repoBlack,
        );
      });
      callback();
    }
  }

  static Future<void> moveSubscriberToWhiteList({
    Topic topic,
    String chatId,
    double minerFee = 0,
    void callback(),
  }) async {
    if (topic.isPrivate && topic.isOwner(NKNClientCaller.currentChatId)) {
      _timer4UploadAction?.cancel();
      _timer4UploadAction = null;
      final repoSub = SubscriberRepo();
      final repoBlack = BlackListRepo();
      final sub = await repoBlack.getByTopicAndChatId(topic.topic, chatId);

      Subscriber updateSubscriber = Subscriber(
        id: 0,
        topic: topic.topic,
        chatId: chatId,
        indexPermiPage: sub?.indexPermiPage ?? -1,
        timeCreate: DateTime.now().millisecondsSinceEpoch,
        uploaded: false,
        subscribed: sub?.subscribed ?? false,
        uploadDone: false,
      );

      await repoSub.insertSubscriber(updateSubscriber);
      await repoBlack.delete(topic.topic, chatId);

      _timer4UploadAction = Timer(Duration(seconds: 15), () async {
        GroupChatPrivateChannel.uploadPermissionMeta(
          topicName: topic.topic,
          minerFee: minerFee,
          accountPubkey: NKNClientCaller.currentChatId,
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
  static Map<String, bool> _topicIsLoading = {};
  static Map<String, bool> _topicIsUploading = {};

  static Future<void> uploadPermissionMeta(
      {String topicName, double minerFee = 0, String accountPubkey, SubscriberRepo repoSub, BlackListRepo repoBlackL}) async {
    if (_topicIsUploading.containsKey(topicName) && _topicIsUploading[topicName]) return;
    _topicIsUploading[topicName] = true;

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
          NLog.e('uploadPermissionMeta E:'+e.toString());
          return null;
        }
      }

      final topicHashed = genTopicHash(topicName);
      upload(int pageIndex, String jsonOfPermission) async {
        try {
          await NKNClientCaller.subscribe(
            identifier: "__${pageIndex}__.__permission__",
            topicHash: topicHashed,
            duration: 400000,
            fee: minerFee.toString(),
            meta: jsonOfPermission,
          );
          await repoSub.updatePageUploaded(topicName, pageIndex);
          await repoBlackL.updatePageUploaded(topicName, pageIndex);
        } catch (e) {
          NLog.e('uploadPermissionMeta'+e.toString());
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
        NLog.w('uploadPermissionMeta | [--, $maxPageIndex] whiteList:\n${whiteList.length}');
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
            await upload(pageIndex, jsonEncode(json));
          }
        }
        ++pageIndex;
      }
      final maxSize = 1024 * 1024 * 3 / 4;
      List<Subscriber> newAdded = List.of(whiteList, growable: true);
      newAdded.retainWhere((el) => el.indexPermiPage < 0);

      var temp = List.of(whiteList);
      temp.retainWhere((el) => el.indexPermiPage == maxPageIndex);
      temp.removeWhere((s) => newAdded.any((it) => s.chatId == it.chatId));
      newAdded.addAll(temp);

      List<BlackList> newAddedBlack = List.of(blackList, growable: true);
      newAddedBlack.retainWhere((el) => el.indexPermiPage < 0);

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
            if (newAdded.isNotEmpty) {
              left.add(newAdded[newAdded.length - 1]);
              newAdded = newAdded.sublist(0, newAdded.length - 1);
            }
            if (newAddedBlack.isNotEmpty) {
              leftBlack.add(newAddedBlack[newAddedBlack.length - 1]);
              newAddedBlack = newAddedBlack.sublist(0, newAddedBlack.length - 1);
            }
          } else {
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
      _topicIsUploading[topicName] = false;
    } catch (e) {
      _topicIsUploading[topicName] = false;
      NLog.e("uploadPermissionMeta, e:"+e.toString());
    }
  }

  static final SubscriberRepo repoSub = SubscriberRepo();
  static final BlackListRepo repoBlack = BlackListRepo();
  static final TopicRepo repoTopic = TopicRepo();

  static Future<int> pullSubscribersPrivateChannel(
      {String topicName,
        ChannelBloc membersBloc,
      void needUploadMetaCallback(String topicName)}) async {
    if (_topicIsLoading.containsKey(topicName) && _topicIsLoading[topicName]) return -1;
    _topicIsLoading[topicName] = true;

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
        final Map<String, dynamic> subscription = await NKNClientCaller.getSubscription(
          topicHash: topicHashed,
          subscriber: "__${pageIndex}__.__permission__.$owner",
        );
        final meta = subscription['meta'] as String;
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
          NLog.e("pullSubscribersPrivateChannel, e:"+e.toString());
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
      final ownerIsMe = ownerIsMeFunc(topicName, NKNClientCaller.currentChatId);
      if (ownerIsMe) {
        try {
          final Map<String, dynamic> subscription = await NKNClientCaller.getSubscription(topicHash: topicHashed, subscriber: NKNClientCaller.currentChatId);
          await repoTopic.updateOwnerExpireBlockHeight(topicName, subscription['expiresAt']);
        } catch (e) {
          NLog.e("pullSubscribersPrivateChannel | updateOwnerExpireBlockHeight. e:"+e.toString());
        }
      }
      var needUploadMeta = false;
      final List<String> chatIdsCurrentlySubscribed = [];

      /// 3. Save the subscribers of this group into the `Black/White List` data table.
      final Map<String, dynamic> subscribersMap = await NKNClientCaller.getSubscribers(topicHash: topicHashed, offset: 0, limit: 10000, meta: false, txPool: true);
      chatIdsCurrentlySubscribed.addAll(subscribersMap.keys);
      for (var chatId in subscribersMap.keys) {
        final inWhiteList = inWhiteListFunc(chatId);
        final isPrmCtl = chatId.contains("__permission__");
        if (!isPrmCtl && (acceptAll || (notInBlackList(chatId) && (inWhiteList || ownerIsMe)))) {
          if (!acceptAll && !inWhiteList) {
            // this case indicates `ownerIsMe`
            final subscriber = await repoSub.getByTopicAndChatId(topicName, chatId);
            if (subscriber == null) {
              needUploadMeta = true;
              Subscriber updateSubsciber = Subscriber(
                  id: 0,
                  topic: topicName,
                  chatId: chatId,
                  indexPermiPage: getPageIndex(chatId, -1),
                  timeCreate: DateTime.now().millisecondsSinceEpoch,
                  uploaded: false,
                  subscribed: true,
                  uploadDone: false
              );
              await repoSub.insertSubscriber(updateSubsciber);
            }
          } else {
            Subscriber updateSubsciber = Subscriber(
                id: 0,
                topic: topicName,
                chatId: chatId,
                indexPermiPage: getPageIndex(chatId, -1),
                timeCreate: DateTime.now().millisecondsSinceEpoch,
                uploaded: true,
                subscribed: true,
                uploadDone: true
            );
            await repoSub.insertSubscriber(updateSubsciber);
          }
        }
      }

      /// 3.1. Save the pubkey (broader scope: including chatId) in the permission-controlled
      /// blacklist into the blacklist data table.
      for (var pubkey in blackListPubkey.keys) {
        final pageIndex = blackListPubkey[pubkey];
        await repoBlack.insertOrUpdate(BlackList(
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
        await repoBlack.insertOrUpdate(BlackList(
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
        await repoBlack.delete(topicName, chatId);
      }

      /// 3.4. If I am not the owner of the group, delete all those not in the permission control blacklist.
      if (!ownerIsMe) {
        final blackList = await repoBlack.getByTopic(topicName);
        blackList.removeWhere((el) => inBlackListFunc(el.chatIdOrPubkey));
        for (final it in blackList) {
          await repoBlack.delete(topicName, it.chatIdOrPubkey);
        }
      }

      /// 3.5. If I am not the owner of the group, and [not] in the subscription list or in the blacklist, delete all
      /// the whitelist (indicating that there is no one in the group),
      /// but do not delete myself from the blacklist (in order to query myself In the blacklist).
      /// And end to return.
      if (!ownerIsMe && (!chatIdsCurrentlySubscribed.contains(NKNClientCaller.currentChatId) || inBlackListFunc(NKNClientCaller.currentChatId))) {
        await repoSub.deleteAll(topicName);
        // Channel reserved. UI need to show.
        //await repoTopic.deleteAll(topicName)
        // UI need black list to show.
        //await repoBlackL.deleteAll(topicName)
        // await repoTopic.updateSubscribersCount(topicName, -1);
        membersBloc.add(ChannelMemberCountEvent(topicName));
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
        final blackList = await repoBlack.getByTopic(topicName);
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
          await repoBlack.delete(topicName, it.chatId);
          final pubkey = getPubkeyFromTopicOrChatId(it.chatId);
          if (pubkey != it.chatId) {
            await repoBlack.delete(topicName, pubkey);
          }
        }

        /// 4.5.1. Delete the uploaded successfully from the whitelist (keep it in the blacklist).
        final temp1 = List.of(beMixed);
        temp1.retainWhere((el) => el.uploadDone);
        for (var it in temp1) {
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
      // // await repoTopic.updateSubscribersCount(topicName, count);
      // membersBloc.add(ChannelMemberCountEvent(topicName));

      // membersBloc.add(ChannelMembersEvent(topicName));
      if (ownerIsMe && needUploadMeta) {
        needUploadMetaCallback(topicName);
      }
      _topicIsLoading[topicName] = false;
      return count;
    } catch (e) {
      _topicIsLoading[topicName] = false;
      NLog.e("pullSubscribersPrivateChannel, e:"+e.toString());
      return -1;
    }
  }
}
