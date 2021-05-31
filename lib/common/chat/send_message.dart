import 'dart:async';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';

import '../locator.dart';

class SendMessage with Tag {
  SendMessage();

  // ignore: close_sinks
  StreamController<MessageSchema> onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => onSavedController.stream;

  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream;

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  Future<MessageSchema?> sendMessage(MessageSchema? schema) async {
    if (schema == null) return null;
    // contact
    contactCommon.addByType(schema.from, ContactType.stranger); // wait
    // TODO:GG topicHandle
    // sqlite
    schema = await _messageStorage.insert(schema);
    if (schema == null) return null;
    onSavedSink.add(schema);
    // sdk send
    Uint8List? pid;
    try {
      if (schema.topic != null) {
        OnMessage? onResult = await chatCommon.publishText(schema.topic!, MessageData.getText(schema));
        pid = onResult?.messageId;
      } else if (schema.to != null) {
        OnMessage? onResult = await chatCommon.sendText(schema.to!, MessageData.getText(schema));
        pid = onResult?.messageId;
      }
    } catch (e) {
      handleError(e);
      return null;
    }
    // result pid
    if (pid != null) {
      schema.pid = pid;
      _messageStorage.updatePid(schema.msgId, schema.pid);
    }
    // update status
    schema = MessageStatus.set(schema, MessageStatus.SendSuccess);
    _messageStorage.updateMessageStatus(schema);
    onUpdateSink.add(schema);
    return schema;
  }

  Future sendReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (tryCount > 3) return;
    try {
      String receipt = MessageData.getReceipt(received.msgId);
      await chatCommon.sendText(received.from, receipt);
      logger.d("$TAG - sendReceipt - sendReceipt:success receipt:$receipt");
    } catch (e) {
      handleError(e);
      logger.d("$TAG - sendReceipt - sendReceipt:fail tryCount:$tryCount");
      Future.delayed(Duration(seconds: 1), () {
        sendReceipt(received, tryCount: tryCount++);
      });
    }
  }
}
