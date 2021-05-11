import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/chat/send_message.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

import '../locator.dart';

/// Receive messages service
class ReceiveMessage {
  ReceiveMessage();

  MessageStorage _messageStorage = MessageStorage();
  ContactStorage _contactStorage = ContactStorage();

  createMessageSchema(raw) {
    Map data = jsonFormat(raw.data);
    if (data != null) {
      Uint8List pid = raw.messageId;
      String to = chat.id;
      String msgId = data['id'] ?? uuid.v4();
      MessageSchema schema = MessageSchema(msgId, raw.src, to, data['contentType']);
      schema.pid = pid;
      schema.isSuccess = true;
      schema.content = data['content'];
      if (data['timestamp'] != null) {
        schema.timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      }
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

  Future messageHandle(MessageSchema schema)async{
    bool isExists = await _messageStorage.queryCount(schema.msgId) > 0;
    if (!isExists) {
      chat.onReceivedMessageStreamSink.add(schema);
      await _messageStorage.insertReceivedMessage(schema);
      chat.onMessageSavedStreamSink.add(schema);
    }
  }

  startReceiveMessage() {
    chat.onMessage.listen((event) async {
      MessageSchema schema = createMessageSchema(event);

      if (schema != null) {
        // handle contact
        contactHandle(schema.from);

        // handle message
        messageHandle(schema);
      }
    });
    receiveTextMessage();
    receiveReceiptMessage();
  }

  receiveTextMessage() {
    chat.onReceivedMessage.where((event) => event.contentType == ContentType.text).listen((event) {
      // receipt message TODO: batch send receipt message
      chat.sendText(event.from, createReceiptMessage(event.msgId));
      // TODO: notification
      // notification.showDChatNotification();
      // TODO
    });
  }

  receiveReceiptMessage() {
    chat.onReceivedMessage.where((event) => event.contentType == ContentType.receipt).listen((event) {
      // TODO: batch update receipt message
      _messageStorage.receiveSuccess(event.msgId);
    });
  }
}
