import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> with AccountDependsBloc, Tag {
  @override
  ChatState get initialState => NotConnect();
  final ContactBloc contactBloc;

  LOG _LOG;
  SubscriberRepo repoSub;
  BlackListRepo repoBl;
  TopicRepo repoTopic;

  ChatBloc({@required this.contactBloc}) {
    _LOG = LOG(tag);
    registerObserver();
  }

  @override
  void onAccountChanged() {
    repoSub = SubscriberRepo(db);
    repoBl = BlackListRepo(db);
    repoTopic = TopicRepo(db);
  }

  @override
  Stream<ChatState> mapEventToState(ChatEvent event) async* {
    if (event is Connect) {
      yield Connected();
    } else if (event is ReceiveMessage) {
      yield* _mapReceiveMessageToState(event);
    } else if (event is SendMessage) {
      yield* _mapSendMessageToState(event);
    } else if (event is RefreshMessages) {
      var unReadCount = await MessageSchema.unReadMessages(db, accountChatId);
      FlutterAppBadger.updateBadgeCount(unReadCount);
      yield MessagesUpdated(target: event.target);
    } else if (event is GetAndReadMessages) {
      yield* _mapGetAndReadMessagesToState(event);
    }
    else if (event is ReceiveMessageList){
      yield* _mapReceiveMessages(event);
    }
  }

  Stream<ChatState> _mapSendMessageToState(SendMessage event) async* {
    var message = event.message;
    if (message.topic == null) {
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(message.to));
      ContactSchema(type: ContactType.stranger, clientAddress: message.to, nknWalletAddress: walletAddress).createContact(db);
    }
    switch (message.contentType) {
      case ContentType.ChannelInvitation:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          pid = await account.client.sendText([message.to], message.toTextData());
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          _LOG.e('_mapSendMessageToState', e);
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.text:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (message.topic != null) {
            if (isPrivateTopic(message.topic)) {
              List<String> dests = await repoSub.getTopicChatIds(message.topic);
              if (!dests.contains(accountChatId)) {
                await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                    client: account.client,
                    topicName: message.topic,
                    accountPubkey: accountPubkey,
                    myChatId: accountChatId,
                    repoSub: repoSub,
                    repoBlackL: repoBl,
                    repoTopic: repoTopic,
                    membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
                    needUploadMetaCallback: (topicName) {

                    });
                if (await repoBl.getByTopicAndChatId(message.topic, accountChatId) != null ||
                    (accountPubkey != accountChatId && await repoBl.getByTopicAndChatId(message.topic, accountPubkey) != null)) {
                  yield GroupEvicted(message.topic);
                  return;
                } else {
                  dests = await repoSub.getTopicChatIds(message.topic);
                  dests.add(accountChatId);
                }
              }
              pid = await account.client.sendText(dests, message.toTextData());
            } else {
              pid = await account.client.publishText(genTopicHash(message.topic), message.toTextData());
            }
          } else {
            Map dataInfo = await _checkIfSendNotification(message);
            pid = await account.client.sendText([message.to], jsonEncode(dataInfo));
          }
          message.pid = pid;
          message.isSendError = false;
          print("Send Text Message");
        } catch (e) {
          message.isSendError = true;
          _LOG.e('_mapSendMessageToState', e);
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.textExtension:
        message.isOutbound = true;
        message.isRead = true;
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
        }
        try {
          Map dataInfo = await _checkIfSendNotification(message);
          var pid = await account.client.sendText([message.to], jsonEncode(dataInfo));
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          _LOG.e('textExtension _mapSendMessageToState', e);
        }
        await message.insert(db, accountPubkey);

        print('Send Text Extension Message');
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.media:
        message.isOutbound = true;
        message.isRead = true;
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
        }
        try {
          var pid;
          if (message.topic != null) {
            if (isPrivateTopic(message.topic)) {
              List<String> dests = await repoSub.getTopicChatIds(message.topic);
              if (!dests.contains(accountChatId)) {
                await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                    client: account.client,
                    topicName: message.topic,
                    accountPubkey: accountPubkey,
                    myChatId: accountChatId,
                    repoSub: repoSub,
                    repoBlackL: repoBl,
                    repoTopic: repoTopic,
                    membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
                    needUploadMetaCallback: (topicName) {});
                if (await repoBl.getByTopicAndChatId(message.topic, accountChatId) != null ||
                    (accountPubkey != accountChatId && await repoBl.getByTopicAndChatId(message.topic, accountPubkey) != null)) {
                  yield GroupEvicted(message.topic);
                  return;
                } else {
                  dests = await repoSub.getTopicChatIds(message.topic);
                  dests.add(accountChatId);
                }
              }
              pid = await account.client.sendText(dests, message.toMediaData());
            } else {
              pid = await account.client.publishText(genTopicHash(message.topic), message.toMediaData());
            }
          } else {
            var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(message.to));
            await ContactSchema(type: ContactType.friend, clientAddress: message.to, nknWalletAddress: walletAddress).createContact(db);
            var contact = await ContactSchema.getContactByAddress(db, message.to);
            String sendData = message.toMeidaWithNotificationData(contact.deviceToken, "[收到图片]");
            pid = await account.client.sendText([message.to], sendData);
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          _LOG.e('Media _mapSendMessageToState', e);
        }
        print('Send Media Message');
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventContactOptions:
        try {
          print('contentType is'+message.contactOptionsType.toString());
          await account.client.sendText([message.to], message.toContentOptionData(message.contactOptionsType));
        } catch (e) {
          _LOG.e('_mapSendMessageToState', e);
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventSubscribe:
        if (message.topic != null) {
          message.isOutbound = true;
          message.isRead = true;
          try {
            var pid;
            if (isPrivateTopic(message.topic)) {
              List<String> dests = await repoSub.getTopicChatIds(message.topic);
              if (dests.length != 0) pid = await account.client.sendText(dests, message.toEventSubscribeData());
            } else {
              pid = await account.client.publishText(genTopicHash(message.topic), message.toEventSubscribeData());
            }
            message.pid = pid;
            message.isSendError = false;
          } catch (e) {
            message.isSendError = true;
            _LOG.e('_mapSendMessageToState', e);
          }
          await message.insert(db, accountPubkey);
          yield MessagesUpdated(target: message.to, message: message);
        }
        return;
      case ContentType.eventUnsubscribe:
        if (message.topic != null) {
          message.isOutbound = true;
          message.isRead = true;
          try {
            var pid;
            if (isPrivateTopic(message.topic)) {
              List<String> dests = await repoSub.getTopicChatIds(message.topic);
              if (dests.length != 0) pid = await account.client.sendText(dests, message.toEventSubscribeData());
            } else {
              pid = await account.client.publishText(genTopicHash(message.topic), message.toEventSubscribeData());
            }
            message.pid = pid;
            message.isSendError = false;
            // delete after message sent.
            await repoSub.deleteAll(message.topic);
          } catch (e) {
            message.isSendError = true;
            _LOG.e('_mapSendMessageToState', e);
          }
//          await message.insert(db, accountPubkey);
//          yield MessagesUpdated(target: message.to, message: message);
        }
        return;
    }
  }

  Stream<ChatState> _mapReceiveMessages(ReceiveMessageList event) async*{
    _LOG.d('_________Receiving  Messages:_________');
    List messageList = event.messageList;
    print('MessageList is '+messageList.toString());

    for (int i = 0; i < messageList.length; i++){
      Map messageInfo = messageList[i];
      MessageSchema message = MessageSchema(from: messageInfo['src'], to: messageInfo['address'], data: messageInfo['data'], pid: messageInfo['pid']);

    }
  }

  _handleSingleMessage(MessageSchema message) async {
    /// 处理单条收到的消
    print('将要处理消息__'+message.content+"__");
    /// 消息已存入数据库
    if (await message.isExist(db)){
      return;
    }
    /// 如果是群消息
    if (message.topic != null){

    }
  }

  _handleGroupMessage(MessageSchema message) async {
    // List<String> dests = await repoSub.getTopicChatIds(message.topic);
    // if (!dests.contains(message.from)) {
    //   if (isPrivateTopic(message.topic)) {
    //     await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
    //         client: account.client,
    //         topicName: message.topic,
    //         accountPubkey: accountPubkey,
    //         myChatId: accountChatId,
    //         repoSub: repoSub,
    //         repoBlackL: repoBl,
    //         repoTopic: repoTopic,
    //         membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
    //         needUploadMetaCallback: (topicName) {});
    //     if (await repoBl.getByTopicAndChatId(message.topic, accountChatId) != null ||
    //         (accountPubkey != accountChatId && await repoBl.getByTopicAndChatId(message.topic, accountPubkey) != null)) {
    //       yield GroupEvicted(message.topic);
    //       return;
    //     } else {
    //       dests = await repoSub.getTopicChatIds(message.topic);
    //       if (!dests.contains(message.from)) {
    //         _LOG.w('$dests not contains ${message.from}');
    //       } else {
    //         _LOG.d('$dests contains ${message.from}');
    //       }
    //     }
    //   } else {
    //     await GroupChatPublicChannel.pullSubscribersPublicChannel(
    //       client: account.client,
    //       topicName: message.topic,
    //       myChatId: accountChatId,
    //       repoSub: SubscriberRepo(db),
    //       repoTopic: TopicRepo(db),
    //       membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
    //     );
    //     dests = await repoSub.getTopicChatIds(message.topic);
    //     if (!dests.contains(message.from)) {
    //       _LOG.w('PUBLIC GROUP MEMBERS not contains ${message.from}');
    //       return;
    //     } else {
    //       _LOG.d('PUBLIC GROUP MEMBERS contains ${message.from}');
    //     }
    //   }
    // } else {
    //   _LOG.d('GROUP MEMBERS contains ${message.from}');
    // }
  }

  Stream<ChatState> _mapReceiveMessageToState(ReceiveMessage event) async* {
    _LOG.d('=======receive  message ==============');
    var message = event.message;
    // TODO: upgrade DB for UNIQUE IND_EX.
    if (await message.isExist(db)) {
      return;
    }
//    if (message.topic != null && LocalStorage.isBlank(accountPubkey, message.topic)) return;
    if (message.topic != null) {
      List<String> dests = await repoSub.getTopicChatIds(message.topic);
      if (!dests.contains(message.from)) {
        if (isPrivateTopic(message.topic)) {
          await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
              client: account.client,
              topicName: message.topic,
              accountPubkey: accountPubkey,
              myChatId: accountChatId,
              repoSub: repoSub,
              repoBlackL: repoBl,
              repoTopic: repoTopic,
              membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
              needUploadMetaCallback: (topicName) {});
          if (await repoBl.getByTopicAndChatId(message.topic, accountChatId) != null ||
              (accountPubkey != accountChatId && await repoBl.getByTopicAndChatId(message.topic, accountPubkey) != null)) {
            yield GroupEvicted(message.topic);
            return;
          } else {
            dests = await repoSub.getTopicChatIds(message.topic);
            if (!dests.contains(message.from)) {
              _LOG.w('$dests not contains ${message.from}');
            } else {
              _LOG.d('$dests contains ${message.from}');
            }
          }
        } else {
          await GroupChatPublicChannel.pullSubscribersPublicChannel(
            client: account.client,
            topicName: message.topic,
            myChatId: accountChatId,
            repoSub: SubscriberRepo(db),
            repoTopic: TopicRepo(db),
            membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
          );
          dests = await repoSub.getTopicChatIds(message.topic);
          if (!dests.contains(message.from)) {
            _LOG.w('PUBLIC GROUP MEMBERS not contains ${message.from}');
            return;
          } else {
            _LOG.d('PUBLIC GROUP MEMBERS contains ${message.from}');
          }
        }
      } else {
        _LOG.d('GROUP MEMBERS contains ${message.from}');
      }
    }
    Topic topic;
    if (message.topic != null) {
      final themeId = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
      topic = Topic(
        id: 0,
        topic: message.topic,
        numSubscribers: -1,
        themeId: themeId,
        timeUpdate: DateTime.now().millisecondsSinceEpoch,
        isTop: false,
        options: OptionsSchema.random(themeId: themeId).toJson(),
      );
      print('Topic Info received'+message.topic);
      repoTopic.insertOrIgnore(topic);
    }

    var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(message.from));
    await ContactSchema(type: ContactType.stranger, clientAddress: message.from, nknWalletAddress: walletAddress).createContact(db);
    var contact = await ContactSchema.getContactByAddress(db, message.from);
    final String title = (topic?.isPrivate ?? false) ? topic.shortName : contact.name;

    if (!contact.isMe && message.contentType != ContentType.contact && Global.isLoadProfile(contact.publicKey)) {
      if (contact.profileExpiresAt == null || DateTime.now().isAfter(contact.profileExpiresAt)) {
        Global.saveLoadProfile(contact.publicKey);
        contact.requestProfile(account.client);
      }
    }

    switch (message.contentType) {
      case ContentType.text:
        if (message.topic != null && message.from == accountChatId) {
          await message.receiptTopic(await db);
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessagesUpdated(target: message.from, message: message);
          return;
        }
        message.receipt(account);
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert(db, accountPubkey);
        var unReadCount = await MessageSchema.unReadMessages(db, accountChatId);
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.ChannelInvitation:
        message.receipt(account);
        message.isSuccess = true;
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert(db, accountPubkey);
        var unReadCount = await MessageSchema.unReadMessages(db, accountChatId);
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.receipt:
        // todo debug
//        LocalNotification.debugNotification('[debug] receipt ' + contact.name, message.msgId);
        await message.receiptMessage(db);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.textExtension:
        message.receipt(account);
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert(db, accountPubkey);

        var unReadCount = await MessageSchema.unReadMessages(db, accountChatId);
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.media:
        if (message.topic != null && message.from == accountChatId) {
          await message.receiptTopic(await db);
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessagesUpdated(target: message.from, message: message);
          return;
        }
        message.receipt(account);
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.loadMedia(accountPubkey);
        await message.insert(db, accountPubkey);
        var unReadCount = await MessageSchema.unReadMessages(db, accountChatId);
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.contact:
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          _LOG.e('_mapReceiveMessageToState', e);
        }
        if (data['requestType'] == RequestType.header) {
          contact.responseProfile(account, accountChatId, type: RequestType.header);
        } else if (data['requestType'] == RequestType.full) {
          contact.responseProfile(account, accountChatId, type: RequestType.full);
        } else {
          // response
          if (data['version'] != contact.profileVersion) {
            if (data['content'] == null) {
              contact.requestProfile(account.client, type: RequestType.full);
            } else {
              await contact.setProfile(db, accountPubkey, data);
              contactBloc.add(LoadContact(address: [message.from]));
            }
          } else {
            _LOG.d('no change profile');
          }
        }
        return;
      case ContentType.eventContactOptions:
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          _LOG.e('_mapReceiveMessageToState', e);
        }
        if (data['optionType'] == 0 || data['optionType'] == '0'){
          print('route1'+data['content'].toString());
          await contact.setBurnOptions(db, data['content']['deleteAfterSeconds']);
        }
        else{
          print('route2');
          await contact.setDeviceToken(db, data['content']['deviceToken']);
        }
        contactBloc.add(LoadContact(address: [contact.clientAddress]));
        message.isSuccess = true;
        message.isRead = true;
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.eventSubscribe:
      case ContentType.eventUnsubscribe:
        Global.removeTopicCache(message.topic);
        if (message.from == accountChatId) {
        } else {
          assert(message.topic.nonNull);
          if (isPrivateTopic(message.topic)) {
            await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                client: account.client,
                topicName: message.topic,
                accountPubkey: accountPubkey,
                myChatId: accountChatId,
                repoSub: repoSub,
                repoBlackL: repoBl,
                repoTopic: repoTopic,
                membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
                needUploadMetaCallback: (topicName) {
                  GroupChatPrivateChannel.uploadPermissionMeta(
                    client: account.client,
                    topicName: topicName,
                    accountPubkey: accountPubkey,
                    repoSub: SubscriberRepo(db),
                    repoBlackL: BlackListRepo(db),
                  );
                });
          } else {
            await GroupChatPublicChannel.pullSubscribersPublicChannel(
              client: account.client,
              topicName: message.topic,
              myChatId: accountChatId,
              repoSub: SubscriberRepo(db),
              repoTopic: TopicRepo(db),
              membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
            );
          }
        }
        return;
    }
  }

  Stream<ChatState> _mapGetAndReadMessagesToState(GetAndReadMessages event) async* {
    if (event.target != null) {
      MessageSchema.getAndReadTargetMessages(db, event.target);
    }
    yield MessagesUpdated(target: event.target);
  }

  ///change burn status
  checkBurnOptions(MessageSchema message, ContactSchema contact) async {
    if (message.topic != null) return;
    print('收到修改阅后即焚'+'__'+contact.options.deleteAfterSeconds.toString());
    print('收到'+'__'+message.deleteAfterSeconds.toString());
    if (message.deleteAfterSeconds != contact.options.deleteAfterSeconds){
      await contact.setBurnOptions(db, contact.options?.deleteAfterSeconds);
    }
    contactBloc.add(LoadContact(address: [contact.clientAddress]));
  }

  Future<int> _getBurnUpdateTime() async {
    int burnUpdateTime;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    burnUpdateTime = await prefs.getInt('set_burn_update_time');
    return burnUpdateTime;
  }

  /// check need send Notification
  Future<Map> _checkIfSendNotification(MessageSchema message) async{
    Map dataInfo;
    if (message.contentType == ContentType.text || message.contentType == ContentType.textExtension){
      dataInfo = jsonDecode(message.toTextData());
    }
    print('Data info message Option is '+dataInfo.toString());
    var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(message.to));
    await ContactSchema(type: ContactType.friend, clientAddress: message.to, nknWalletAddress: walletAddress).createContact(db);
    var contact = await ContactSchema.getContactByAddress(db, message.to);
    if (contact.deviceToken != null && contact.deviceToken.length > 0){
      String pushContent = NL10ns.of(Global.appContext).notification_push_content;
      pushContent = "from:"+accountChatId.substring(0, 8) + "...";
      print('Send Push notification content is '+pushContent);
      dataInfo['deviceToken'] = contact.deviceToken;
      dataInfo['pushContent'] = pushContent;

      if (message.contentType == ContentType.media){
        dataInfo = jsonDecode(message.toMeidaWithNotificationData(contact.deviceToken, pushContent));
      }
    }
    print("final send data is"+dataInfo.toString());
    return dataInfo;
  }
}

abstract class ChatState {
  const ChatState();
}

class NotConnect extends ChatState {}

class Connected extends ChatState {}

class MessagesUpdated extends ChatState {
  final String target;
  final MessageSchema message;

  const MessagesUpdated({this.target, this.message});
}

class GroupEvicted extends ChatState {
  final String topicName;

  const GroupEvicted(this.topicName);
}

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class Connect extends ChatEvent {}

class RefreshMessages extends ChatEvent {
  final String target;

  const RefreshMessages({this.target});
}

class ReceiveMessage extends ChatEvent {
  final MessageSchema message;

  const ReceiveMessage(this.message);
}

class ReceiveMessageList extends ChatEvent{
  final List messageList;

  const ReceiveMessageList(this.messageList);
}

class SendMessage extends ChatEvent {
  final MessageSchema message;

  const SendMessage(this.message);
}

class GetAndReadMessages extends ChatEvent {
  final String target;

  const GetAndReadMessages({this.target});
}
