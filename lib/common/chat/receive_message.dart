import 'dart:async';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/chat/send_message.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

import '../locator.dart';

/// Receive messages service
class ReceiveMessage {
  ReceiveMessage();

  MessageStorage _messageStorage = MessageStorage();
  ContactStorage _contactStorage = ContactStorage();

  MessageSchema createMessageSchema(OnMessage raw) {
    if (raw == null && raw.data != null) return null;
    Map data = jsonFormat(raw.data);
    if (data != null) {
      MessageSchema schema = MessageSchema(data['id'], raw.src, chat.id, data['contentType']);
      schema.pid = raw.messageId;
      schema.isSuccess = true;
      schema.content = data['content'];
      schema.options = data['options'];
      if (data['timestamp'] != null) {
        schema.timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      }

      // TODO:GG
      // String topic;
      // DateTime receiveTime;
      // DateTime deleteTime;
      // bool isRead = false;
      // bool isOutbound = false;
      // bool isSendError = false;
      // MessageStatus messageStatus;

      return schema;
    }
    return null;
  }

  Future contactHandle(String clientAddress) async {
    int count = await _contactStorage.queryCountByClientAddress(clientAddress);
    if (count == 0) {
      String walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
      await _contactStorage.insertContact(ContactSchema(
        type: ContactType.stranger,
        clientAddress: clientAddress,
        nknWalletAddress: walletAddress,
      ));
    }
  }

  Future messageHandle(MessageSchema schema) async {
    bool isExists = await _messageStorage.queryCount(schema.msgId) > 0;
    if (!isExists) {
      chat.onReceivedMessageSink.add(schema);
      await _messageStorage.insertReceivedMessage(schema);
      chat.onMessageSavedSink.add(schema);
    }
  }

  startReceiveMessage() {
    // onMessages
    StreamSubscription subscription = chat.onMessageStream.listen((OnMessage event) async {
      MessageSchema schema = createMessageSchema(event);
      if (schema != null) {
        // handle contact
        contactHandle(schema.from);

        // handle message
        messageHandle(schema);
      }
    });
    chat.onMessageStreamSubscriptions.add(subscription);

    // onReceiveMessages
    receiveTextMessage();
    receiveReceiptMessage();
  }

  receiveTextMessage() {
    StreamSubscription subscription = chat.onReceivedMessageStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) {
      // receipt message TODO: batch send receipt message
      chat.sendText(event.from, createReceiptMessage(event.msgId));
      // TODO: notification
      // notification.showDChatNotification();
      // TODO
      logger.d("receiveTextMessage -> $event");
    });
    chat.onReceiveMessageStreamSubscriptions.add(subscription);
  }

  receiveReceiptMessage() {
    StreamSubscription subscription = chat.onReceivedMessageStream.where((event) => event.contentType == ContentType.receipt).listen((MessageSchema event) {
      // TODO: batch update receipt message
      _messageStorage.receiveSuccess(event.msgId);
    });
    chat.onReceiveMessageStreamSubscriptions.add(subscription);
  }
}
