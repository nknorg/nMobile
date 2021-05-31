import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
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

  Future<MessageSchema?> sendMessage(MessageSchema? schema, String? msgData) async {
    if (schema == null || msgData == null) return null;
    // contact
    contactCommon.addByType(schema.from, ContactType.stranger); // wait
    // TODO:GG topicHandle
    // sqlite
    schema = await _messageStorage.insert(schema);
    if (schema == null) return null;
    // view show
    onSavedSink.add(schema);
    // sdk send
    Uint8List? pid;
    try {
      if (schema.topic != null) {
        OnMessage? onResult = await chatCommon.publishMessage(schema.topic!, msgData);
        pid = onResult?.messageId;
      } else if (schema.to != null) {
        OnMessage? onResult = await chatCommon.sendMessage(schema.to!, msgData);
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

  // NO DB insert
  Future sendMessageReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (tryCount > 3) return;
    try {
      String receipt = MessageData.getReceipt(received.msgId);
      await chatCommon.sendMessage(received.from, receipt);
      logger.d("$TAG - sendMessageReceipt - success receipt:$receipt");
    } catch (e) {
      handleError(e);
      logger.d("$TAG - sendMessageReceipt - fail tryCount:$tryCount");
      Future.delayed(Duration(seconds: 1), () {
        sendMessageReceipt(received, tryCount: tryCount++);
      });
    }
  }

  Future<MessageSchema?> sendMessageText(String? dest, String? content, {bool toast = true}) {
    if (chatCommon.id == null || dest == null || content == null || content.isEmpty) {
      Toast.show(S.of(Global.appContext).failure);
      return Future.value(null);
    }
    MessageSchema schema = MessageSchema.fromSend(
      uuid.v4(),
      chatCommon.id!,
      ContentType.text,
      to: dest,
      content: content,
    );
    return sendMessage(schema, MessageData.getText(schema));
  }

  Future<MessageSchema?> sendMessageImage(String? dest, File? content) async {
    if (chatCommon.id == null || dest == null || content == null || (!await content.exists())) {
      Toast.show(S.of(Global.appContext).failure);
      return null;
    }
    MessageSchema schema = MessageSchema.fromSend(
      uuid.v4(),
      chatCommon.id!,
      ContentType.image,
      to: dest,
      content: content,
    );
    return sendMessage(schema, await MessageData.getImage(schema));
  }
}
