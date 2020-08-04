import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/permission.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/utils/log_tag.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> with AccountDependsBloc, Tag {
  @override
  ChatState get initialState => NotConnect();
  final ContactBloc contactBloc;

  LOG _LOG;

  ChatBloc({@required this.contactBloc}) {
    _LOG = LOG(tag);
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
          debugPrint(e);
          debugPrintStack();
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
              List<String> dests = await Permission.getPrivateChannelDests(account, message.topic);
              if (!dests.contains(accountChatId)) {
                dests.add(accountChatId);
                TopicSchema(topic: message.topic).getPrivateOwnerMetaAction(account);
                TopicSchema(topic: message.topic).getSubscribers(account, cache: false);
              }
              pid = await account.client.sendText(dests, message.toTextData());
            } else {
              pid = await account.client.publishText(genChannelId(message.topic), message.toTextData());
            }
          } else {
            pid = await account.client.sendText([message.to], message.toTextData());
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
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
          debugPrint(e);
          debugPrintStack();
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
              List<String> dests = await Permission.getPrivateChannelDests(account, message.topic);
              pid = await account.client.sendText(dests, message.toMediaData());
            } else {
              pid = await account.client.publishText(genChannelId(message.topic), message.toMediaData());
            }
          } else {
            pid = await account.client.sendText([message.to], message.toMediaData());
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          debugPrint(e);
          debugPrintStack();
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventContactOptions:
        try {
          await account.client.sendText([message.to], message.toActionContentOptionsData());
        } catch (e) {
          debugPrint(e);
          debugPrintStack();
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.dchatSubscribe:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (message.topic != null) {
            if (isPrivateTopic(message.topic)) {
              List<String> dests = await Permission.getPrivateChannelDests(account, message.topic);
              if (dests.length != 0) pid = await account.client.sendText(dests, message.toDchatSubscribeData());
            } else {
              pid = await account.client.publishText(genChannelId(message.topic), message.toDchatSubscribeData());
            }
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventSubscribe:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (isPrivateTopic(message.topic) && message.topic != null) {
            List<String> dests = await Permission.getPrivateChannelDests(account, message.topic);
            pid = await account.client.sendText(dests, message.toEventSubscribeData());
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        return;
    }
  }

  Stream<ChatState> _mapReceiveMessageToState(ReceiveMessage event) async* {
    _LOG.d('=======receive  message ==============');
    var message = event.message;
    if (await message.isExist(db)) {
      return;
    }

    if (message.topic != null && LocalStorage.isBlank(accountPubkey, message.topic)) return;

    if (message.topic != null && isPrivateTopic(message.topic)) {
      List<String> dests = await Permission.getPrivateChannelDests(account, message.topic);
      if (!dests.contains(message.from)) {
        TopicSchema(topic: message.topic).getPrivateOwnerMetaAction(account);
        TopicSchema(topic: message.topic).getSubscribers(account, cache: false);
        _LOG.d('$dests not contains ${message.from}');
        return;
      } else {
        _LOG.d('$dests contains ${message.from}');
      }
    }

    var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(message.from));
    await ContactSchema(type: ContactType.stranger, clientAddress: message.from, nknWalletAddress: walletAddress).createContact(db);
    var contact = await ContactSchema.getContactByAddress(db, message.from);
    var title = contact.name;

    if (!contact.isMe && message.contentType != ContentType.contact && Global.isLoadProfile(contact.publicKey)) {
      if (contact.profileExpiresAt == null || DateTime.now().isAfter(contact.profileExpiresAt)) {
        Global.saveLoadProfile(contact.publicKey);
        contact.requestProfile(account.client);
      }
    }

    if (message.topic != null) {
      title = '[${message.topic}] $title';

      String topicType = TopicType.public;
      String owner;
      if (isPrivateTopic(message.topic)) {
        topicType = TopicType.private;
        owner = getOwnerPubkeyByTopic(message.topic);
        title = TopicSchema(topic: message.topic, type: TopicType.private).subTitle;
      }
      TopicSchema topicSchema = TopicSchema(topic: message.topic, type: topicType, owner: owner, updateTime: DateTime.now());
      topicSchema.insertIfNoData(db, accountPubkey);
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
      case ContentType.eventSubscribe:
        Global.removeTopicCache(message.topic);
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
          debugPrint(e.message);
          debugPrintStack();
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
          print(e);
        }
        await contact.setBurnOptions(db, data['content']['deleteAfterSeconds']);
        contactBloc.add(LoadContact(address: [contact.clientAddress]));
        message.isSuccess = true;
        message.isRead = true;
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.dchatSubscribe:
        if (message.topic != null && message.from == accountChatId) {
          await message.receiptTopic(await db);
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessagesUpdated(target: message.from, message: message);
          return;
        }
        message.isSuccess = true;
        message.isRead = true;
        await message.insert(db, accountPubkey);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.eventNodeOnline:
        _LOG.i('收到${message.from}');
        CdnMiner.getAllCdnMiner(db).then((list) {
          var model = list.firstWhere((m) => m.nshId == message.from, orElse: () => null);
          if (model == null) {
            _LOG.i('开始添加${message.from}');
            CdnMiner(message.from).insertOrUpdate(db);
          } else {
            _LOG.i('已存在${message.from}');
          }
        });

//        message.receipt();
        message.contentType = ContentType.text;
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert(db, accountPubkey);
        var unReadCount = await MessageSchema.unReadMessages(db, accountChatId);
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
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
    if (message.topic != null || contact?.options?.deleteAfterSeconds == null) return;
    contact.setBurnOptions(db, null);
    contactBloc.add(LoadContact(address: [contact.clientAddress]));
  }
}
