import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

import '../locator.dart';

/// Receive messages service
class ReceiveMessage {
  ReceiveMessage();

  MessageStorage _messageStorage = MessageStorage();

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

  startReceiveMessage() {
    chat.onMessage.listen((event) async {
      MessageSchema schema = createMessageSchema(event);
      if (schema != null) {
        bool isExists = await _messageStorage.queryCount(schema.msgId) > 0;
        if (!isExists) {
          await _messageStorage.insertReceivedMessage(schema);
          chat.onMessageSavedController.sink.add(event);
        }
      }
    });
  }
}
