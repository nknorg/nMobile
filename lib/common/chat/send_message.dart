import 'dart:async';

import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';

import '../locator.dart';

class SendMessage {
  SendMessage();

  // ignore: close_sinks
  StreamController<MessageSchema> onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => onSavedController.stream; // TODO:GG
  List<StreamSubscription> onSavedStreamSubscriptions = <StreamSubscription>[];

  // ignore: close_sinks
  StreamController<MessageSchema> _onSendController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSendSink => _onSendController.sink;
  Stream<MessageSchema> get onSendStream => _onSendController.stream; // TODO:GG
  List<StreamSubscription> onSendSubscriptions = <StreamSubscription>[];

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  Future<MessageSchema?> sendMessage(MessageSchema? schema) async {
    if (schema == null) return null;
    // contact
    contactCommon.addByType(schema.from, ContactType.stranger);
    // TODO:GG topic
    // sqlite
    schema = await _messageStorage.insert(schema);
    if (schema == null) return null;
    onSavedSink.add(schema);
    // send
    try {
      if (schema.topic != null) {
        await chatCommon.publishText(schema.topic!, MessageData.getText(schema));
      } else if (schema.to != null) {
        await chatCommon.sendText(schema.to!, MessageData.getText(schema));
        onSendSink.add(schema);
        return schema;
      }
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future sendReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (tryCount > 3) return;
    try {
      await chatCommon.sendText(received.from, MessageData.getReceipt(received.msgId));
      logger.i("send_messages - sendReceipt:success target:$received");
    } catch (e) {
      handleError(e);
      logger.i("send_messages - sendReceipt:fail tryCount:$tryCount");
      Future.delayed(Duration(seconds: 1), () {
        sendReceipt(received, tryCount: tryCount++);
      });
    }
  }
}
