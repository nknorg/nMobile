import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/utils.dart';

import '../locator.dart';

/// Receive messages service
class ReceiveMessage {
  ReceiveMessage();

  MessageStorage _messageStorage = MessageStorage();

  startReceiveMessage() {
    chat.onMessage.listen((event) async {
      Map data = jsonFormat(event.data);
      if (data != null) {
        Uint8List pid = event.messageId;
        String to = chat.id;
        String msgId = data['id'];
        MessageSchema schema = MessageSchema(msgId, event.src, to, data['contentType']);
        schema.pid = pid;
        schema.isSuccess = true;
        schema.content = data['content'];
        if (data['timestamp'] != null) {
          schema.timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
        }
        bool isExists = await _messageStorage.queryCount(msgId) > 0;
        if (!isExists) {
          _messageStorage.insertReceivedMessage(schema);
        }
      }
    });
  }
}
