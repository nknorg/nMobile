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
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/log_tag.dart';

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
//                    GroupChatPrivateChannel.uploadPermissionMeta(
//                        client: account.client,
//                        topicName: topicName,
//                        accountPubkey: accountPubkey,
//                        repoSub: repoSub,
//                        repoBlackL: repoBl,
//                        membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext));
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
            pid = await account.client.sendText([message.to], message.toTextData());
          }
          message.pid = pid;
          message.isSendError = false;
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
          var pid = await account.client.sendText([message.to], message.toTextData());
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          _LOG.e('_mapSendMessageToState', e);
        }
        await message.insert(db, accountPubkey);
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
            pid = await account.client.sendText([message.to], message.toMediaData());
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          _LOG.e('_mapSendMessageToState', e);
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventContactOptions:
        try {
          await account.client.sendText([message.to], message.toActionContentOptionsData());
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

  Stream<ChatState> _mapReceiveMessageToState(ReceiveMessage event) async* {
    _LOG.d('=======receive  message ==============');
    var message = event.message;
    // TODO: upgrade DB for UNIQUE INDEX.
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
        blockHeightExpireAt: -1,
        isTop: false,
        options: OptionsSchema.random(themeId: themeId).toJson(),
      );
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
        if (message.deleteAfterSeconds != contact.options.deleteAfterSeconds) {
          await contact.setBurnOptions(db, message.deleteAfterSeconds);
          contactBloc.add(LoadContact(address: [contact.clientAddress]));
        }
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
        await contact.setBurnOptions(db, data['content']['deleteAfterSeconds']);
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
    await contact.setBurnOptions(db, contact.options?.deleteAfterSeconds);
    contactBloc.add(LoadContact(address: [contact.clientAddress]));
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

class SendMessage extends ChatEvent {
  final MessageSchema message;

  const SendMessage(this.message);
}

class GetAndReadMessages extends ChatEvent {
  final String target;

  const GetAndReadMessages({this.target});
}
