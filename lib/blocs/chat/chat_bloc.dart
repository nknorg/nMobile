import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/permission.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/utils/nlog_util.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  @override
  ChatState get initialState => NotConnect();
  final ContactBloc contactBloc;

  ChatBloc({@required this.contactBloc});

  @override
  Stream<ChatState> mapEventToState(ChatEvent event) async* {
    if (event is Connect) {
      yield Connected();
    } else if (event is ReceiveMessage) {
      yield* _mapReceiveMessageToState(event);
    } else if (event is SendMessage) {
      yield* _mapSendMessageToState(event);
    } else if (event is RefreshMessages) {
      var unReadCount = await MessageSchema.unReadMessages();
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
      ContactSchema(type: ContactType.stranger, clientAddress: message.to, nknWalletAddress: walletAddress).createContact();
    }
    switch (message.contentType) {
      case ContentType.ChannelInvitation:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          pid = await NknClientPlugin.sendText([message.to], message.toTextData());
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          debugPrint(e);
          debugPrintStack();
        }
        await message.insert();
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.text:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (message.topic != null) {
            if (isPrivateTopic(message.topic)) {
              List<String> dests = await Permission.getPrivateChannelDests(message.topic);
              if (!dests.contains(Global.currentClient.address)) {
                dests.add(Global.currentClient.address);
                TopicSchema(topic: message.topic).getPrivateOwnerMetaAction();
                TopicSchema(topic: message.topic).getSubscribers(cache: false);
              }
              pid = await NknClientPlugin.sendText(dests, message.toTextData());
            } else {
              pid = await NknClientPlugin.publish(genChannelId(message.topic), message.toTextData());
            }
          } else {
            pid = await NknClientPlugin.sendText([message.to], message.toTextData());
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        await message.insert();
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.textExtension:
        message.isOutbound = true;
        message.isRead = true;
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
        }
        try {
          var pid = await NknClientPlugin.sendText([message.to], message.toTextData());
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          debugPrint(e);
          debugPrintStack();
        }
        await message.insert();
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
              List<String> dests = await Permission.getPrivateChannelDests(message.topic);
              pid = await NknClientPlugin.sendText(dests, message.toMediaData());
            } else {
              pid = await NknClientPlugin.publish(genChannelId(message.topic), message.toMediaData());
            }
          } else {
            pid = await NknClientPlugin.sendText([message.to], message.toMediaData());
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
          debugPrint(e);
          debugPrintStack();
        }
        await message.insert();
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventContactOptions:
        try {
          var pid = await NknClientPlugin.sendText([message.to], message.toActionContentOptionsData());
        } catch (e) {
          debugPrint(e);
          debugPrintStack();
        }

        return;
      case ContentType.dchatSubscribe:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (message.topic != null) {
            if (isPrivateTopic(message.topic)) {
//              LogUtil.v('开始发送私有群');
              List<String> dests = await Permission.getPrivateChannelDests(message.topic);
              if (dests.length != 0) pid = await NknClientPlugin.sendText(dests, message.toDchatSubscribeData());
            } else {
              pid = await NknClientPlugin.publish(genChannelId(message.topic), message.toDchatSubscribeData());
            }
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        await message.insert();
        yield MessagesUpdated(target: message.to, message: message);
        return;
      case ContentType.eventSubscribe:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (isPrivateTopic(message.topic) && message.topic != null) {
            List<String> dests = await Permission.getPrivateChannelDests(message.topic);
            pid = await NknClientPlugin.sendText(dests, message.toEventSubscribeData());
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
    NLog.d('=======receive  message ==============');
    var message = event.message;
    if (await message.isExist()) {
      return;
    }
    if (message.topic != null && isPrivateTopic(message.topic)) {
      List<String> dests = await Permission.getPrivateChannelDests(message.topic);
      if (!dests.contains(message.from)) {
        TopicSchema(topic: message.topic).getPrivateOwnerMetaAction();
        TopicSchema(topic: message.topic).getSubscribers(cache: false);
        NLog.d('$dests not contains ${message.from}');
        return;
      } else {
        NLog.d('$dests contains ${message.from}');
      }
    }

    var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(message.from));
    await ContactSchema(type: ContactType.stranger, clientAddress: message.from, nknWalletAddress: walletAddress).createContact();
    var contact = await ContactSchema.getContactByAddress(message.from);
    var title = contact.name;

    if (!contact.isMe && message.contentType != ContentType.contact && Global.isLoadProfile(contact.publickKey)) {
      if (contact.profileExpiresAt == null || DateTime.now().isAfter(contact.profileExpiresAt)) {
        Global.saveLoadProfile(contact.publickKey);
        contact.requestProfile();
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
      topicSchema.insertIfNoData();
    }
    switch (message.contentType) {
      case ContentType.text:
        if (message.topic != null && message.from == Global.currentClient.address) {
          await message.receiptTopic();
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessagesUpdated(target: message.from, message: message);
          return;
        }
        message.receipt();
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.ChannelInvitation:
        message.receipt();
        message.isSuccess = true;
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.eventSubscribe:
        Global.removeTopicCache(message.topic);

        return;
      case ContentType.receipt:
        // todo debug
        LocalNotification.debugNotification('[debug] receipt ' + contact.name, message.msgId);
        await message.receiptMessage();
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.textExtension:
        message.receipt();
        message.isSuccess = true;
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
        if (message.deleteAfterSeconds != contact.options.deleteAfterSeconds) {
          await contact.setBurnOptions(message.deleteAfterSeconds);
          contactBloc.add(LoadContact(address: [contact.clientAddress]));
        }
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.media:
        if (message.topic != null && message.from == Global.currentClient.address) {
          await message.receiptTopic();
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessagesUpdated(target: message.from, message: message);
          return;
        }
        message.receipt();
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        LocalNotification.messageNotification(title, message.content, message: message);
        await message.loadMedia();
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
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
          contact.responseProfile(type: RequestType.header);
        } else if (data['requestType'] == RequestType.full) {
          contact.responseProfile(type: RequestType.full);
        } else {
          // response
          if (data['version'] != contact.profileVersion) {
            if (data['content'] == null) {
              contact.requestProfile(type: RequestType.full);
            } else {
              await contact.setProfile(data);
              contactBloc.add(LoadContact(address: [message.from]));
            }
          } else {
            NLog.d('no change profile');
          }
        } //
        return;
      case ContentType.eventContactOptions:
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          print(e);
        }
        await contact.setBurnOptions(data['content']['deleteAfterSeconds']);
        contactBloc.add(LoadContact(address: [contact.clientAddress]));
        message.isSuccess = true;
        message.isRead = true;
        await message.insert();
        yield MessagesUpdated(target: message.from, message: message);
        return;
      case ContentType.dchatSubscribe:
        if (message.topic != null && message.from == Global.currentClient.address) {
          await message.receiptTopic();
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessagesUpdated(target: message.from, message: message);
          return;
        }
        message.isSuccess = true;
        message.isRead = true;
        await message.insert();
        yield MessagesUpdated(target: message.from, message: message);
        return;
    }
  }

  Stream<ChatState> _mapGetAndReadMessagesToState(GetAndReadMessages event) async* {
    if (event.target != null) {
      MessageSchema.getAndReadTargetMessages(event.target);
    }

    yield MessagesUpdated(target: event.target);
  }

  ///change burn status
  checkBurnOptions(MessageSchema message, ContactSchema contact) {
    if (message.topic != null || contact?.options?.deleteAfterSeconds == null) return;
    contact.setBurnOptions(null);
    contactBloc.add(LoadContact(address: [contact.clientAddress]));
  }
}
