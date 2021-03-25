/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';

import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/data/contact_data_center.dart';
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

  static Future<ContactSchema> checkContactIfExists(
      String clientAddress) async {
    var contact = await ContactSchema.fetchContactByAddress(clientAddress);
    if (contact == null) {
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(
          getPublicKeyByClientAddr(clientAddress));
      if (clientAddress != null) {
        NLog.w('Insert contact stranger__' + clientAddress.toString());
      } else {
        NLog.w('got clientAddress Wrong!!!');
      }
      if (walletAddress == null) {
        NLog.w('got walletAddress Wrong!!!');
      }
      contact = ContactSchema(
          type: ContactType.stranger,
          clientAddress: clientAddress,
          nknWalletAddress: walletAddress);
      await contact.insertContact();
    }
    return contact;
  }

  static Future<bool> checkMeInChannel(
      String topicName, String myChatId) async {
    try {
      final topicHashed = genTopicHash(topicName);
      NKNClientCaller.getSubscribers(
              topicHash: topicHashed,
              offset: 0,
              limit: 10000,
              meta: false,
              txPool: true)
          .then((subscribersMap) async {
        if (subscribersMap.keys.contains(myChatId)) {
          return true;
        }
      });
      return false;
    } catch (e) {
      if (e != null) {
        NLog.w('group_chat_helper E:' + e.toString());
      }
      return false;
    }
  }
}

class GroupChatHelper {
  static final SubscriberRepo _subscriberRepo = SubscriberRepo();
  static final TopicRepo _topicRepo = TopicRepo();

  static Future<List<String>> fetchGroupMembers(String topicName) async {
    List<String> memberList =
        await _subscriberRepo.getAllSubscriberByTopic(topicName);
    if (memberList != null && memberList.length > 0) {
      if (topicName != null) {
        NLog.w('Got Topic__' +
            topicName.toString() +
            'count is__' +
            memberList.length.toString());
      }
      return memberList;
    } else {
      if (topicName != null) {
        NLog.w('Wrong get no group member__' + topicName);
      } else {
        NLog.w('Wrong!!! topic Name is null');
      }
      return null;
    }
  }

  static Future<Topic> fetchTopicInfoByName(String topicName) async {
    Topic topicInfo = await _topicRepo.getTopicByName(topicName);
    return topicInfo;
  }

  static insertTopicIfNotExists(String topicName) async {
    if (topicName != null) {
      await _topicRepo.insertTopicByTopicName(topicName);
      await insertSelfSubscriber(topicName);

      NLog.w('Insert topicName __' + topicName.toString());
    } else {
      NLog.w('Wrong!!! insertTopicIfNotExists no topicName');
    }
  }

  static insertSelfSubscriber(String topicName) async {
    Subscriber selfSub = await _subscriberRepo.getByTopicAndChatId(
        topicName, NKNClientCaller.currentChatId);

    if (selfSub == null) {
      selfSub = Subscriber(
          id: 0,
          topic: topicName,
          chatId: NKNClientCaller.currentChatId,
          timeCreate: DateTime.now().millisecondsSinceEpoch,
          blockHeightExpireAt: -1,
          memberStatus: MemberStatus.MemberSubscribed);
    }
    else{
      NLog.w('selfSub is____'+selfSub.topic.toString());
      NLog.w('selfSub is____'+selfSub.chatId.toString());
    }
    await _subscriberRepo.insertSubscriber(selfSub);
  }

  static Future<bool> checkMemberIsInGroup(
      String memberId, String topicName) async {
    Subscriber subscriber =
        await _subscriberRepo.getByTopicAndChatId(topicName, memberId);
    if (subscriber != null) {
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> removeTopicAndSubscriber(String topicName) async {
    await _topicRepo.delete(topicName);
    await _subscriberRepo.deleteAll(topicName);
    return true;
  }

  static Future<void> subscribeTopic(
      {String topicName,
      ChatBloc chatBloc,
      void callback(bool success, dynamic error)}) async {
    try {
      final topicHash =
          await NKNClientCaller.subscribe(topicHash: genTopicHash(topicName));
      if (nonEmpty(topicHash) && topicHash.length >= 32) {
        Topic topicInfo = await GroupChatHelper.fetchTopicInfoByName(topicName);
        if (topicInfo == null) {
          await GroupChatHelper.insertTopicIfNotExists(topicName);

          topicInfo = await GroupChatHelper.fetchTopicInfoByName(topicName);
          int currentBlockHeight = await NKNClientCaller.fetchBlockHeight();
          if (currentBlockHeight > 0) {
            TopicRepo()
                .updateOwnerExpireBlockHeight(topicName, currentBlockHeight);
            if (topicInfo.topic != null) {
              NLog.w('Insert Topic__' +
                  topicInfo.topic +
                  'Success' +
                  '__' +
                  currentBlockHeight.toString());
            }
          } else {
            NLog.w('Wrong!!!fetchBlockHeight___E:' +
                currentBlockHeight.toString());
          }
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
          NKNClientCaller.getSubscription(
                  topicHash: topicHash,
                  subscriber: NKNClientCaller.currentChatId)
              .then((subscription) {
            if (subscription['expiresAt'] != null) {
              if (subscription['expiresAt'] == null ||
                  subscription['expiresAt'] == 0) {
                NLog.w('Wrong!!! expiresAt is 0');
                NLog.w('Wrong!!! expiresAt is null' + subscription.toString());
              } else {
                TopicRepo().updateOwnerExpireBlockHeight(
                    topicName, int.parse(subscription['expiresAt'].toString()));
                if (topicInfo.topic != null && subscription != null) {
                  NLog.w('UpdateTopic__' +
                      topicInfo.topic +
                      'Success' +
                      '__' +
                      subscription.toString());
                } else {
                  NLog.w('Wrong!!! topic.topic or subscription is null');
                }
              }
            }
          });
        }
      } else {
        NLog.w('callback callback Exception:' + topicHash.toString());
        callback(false, null);
      }
    } catch (e) {
      if (e != null) {
        NLog.w('Group_Chat_Helper__ got Exception:' + e.toString());
      }
      if (e.toString().contains('duplicate subscription exist in block')) {
        Topic topicInfo = await GroupChatHelper.fetchTopicInfoByName(topicName);
        if (topicInfo != null) {
          var sendMsg = MessageSchema.fromSendData(
            from: NKNClientCaller.currentChatId,
            topic: topicName,
            contentType: ContentType.eventSubscribe,
          );
          sendMsg.content = sendMsg.toEventSubscribeData();
          chatBloc.add(SendMessageEvent(sendMsg));
          callback(true, null);
        }
        await GroupChatHelper.insertTopicIfNotExists(topicName);
      } else {
        callback(false, e);
      }
    }
  }

  static deleteTopicWithSubscriber(String topic) {
    if (topic != null) {
      _topicRepo.delete(topic);
      _subscriberRepo.deleteAll(topic);
    } else {
      NLog.w('Delete topic Wrong!!! topic is null');
    }
  }

  static Future<bool> deleteSubscriberOfTopic(String topicName, String chatId) async{
    bool result = await _subscriberRepo.delete(topicName, chatId);
    return result;
  }

  static Future<void> unsubscribeTopic(
      {String topicName,
      ChatBloc chatBloc,
      void callback(bool success, dynamic error)}) async {
    try {
      final hash =
          await NKNClientCaller.unsubscribe(topicHash: genTopicHash(topicName));
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
      if (e != null) {
        NLog.w('unsubscribeTopic E:' + e.toString());
      }
      if (e.toString().contains('duplicate subscription exist in block') ||
          e.toString().contains('can not append tx to txpool')) {
        deleteTopicWithSubscriber(topicName);
        callback(true, null);
        return;
      }
      callback(false, e);
    }
  }
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

bool ownerIsMeFunc(String topic, String myPubkey) =>
    getPubkeyFromTopicOrChatId(topic) == myPubkey;
