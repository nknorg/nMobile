import 'dart:async';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';

import '../locator.dart';

/// Receive messages service
class ReceiveMessage {
  ReceiveMessage();

  MessageStorage _messageStorage = MessageStorage();
  ContactStorage _contactStorage = ContactStorage();

  startReceiveMessage() {
    // onMessages
    StreamSubscription subscription = chat.onMessageStream.listen((OnMessage event) async {
      logger.i("onMessageStream -> messageId:${event.messageId} - src:${event.src} - data:${event.data} - type:${event.type} - encrypted:${event.encrypted}");
      MessageSchema schema = MessageSchema.fromReceive(event);
      if (schema != null) {
        contactHandle(schema.from);
        messageHandle(schema);
      }
    });
    chat.onMessageStreamSubscriptions.add(subscription);

    // onReceiveMessages
    receiveTextMessage();
    receiveReceiptMessage();
  }

  Future contactHandle(String clientAddress) async {
    int count = await _contactStorage.queryCountByClientAddress(clientAddress);
    if (count == 0) {
      await contact.add(ContactSchema(
        type: ContactType.stranger,
        clientAddress: clientAddress,
        // nknWalletAddress: await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress)),
      ));
    }
  }

  Future messageHandle(MessageSchema schema) async {
    bool isExists = (await _messageStorage.queryCount(schema.msgId)) > 0;
    if (!isExists) {
      chat.onReceivedMessageSink.add(schema);
      await _messageStorage.insertReceivedMessage(schema);
      chat.onMessageSavedSink.add(schema);
    }
  }

  receiveTextMessage() {
    StreamSubscription subscription = chat.onReceivedMessageStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) {
      // receipt message TODO: batch send receipt message
      chat.sendText(event.from, sendMessage.createReceiptMessage(event.msgId));
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
