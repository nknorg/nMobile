import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:uuid/uuid.dart';

import '../locator.dart';

class SendMessage with Tag {
  SendMessage();

  // ignore: close_sinks
  StreamController<MessageSchema> onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => onSavedController.stream.distinct((prev, next) => prev.msgId == next.msgId);

  // ignore: close_sinks
  StreamController<MessageSchema> _onUpdateController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onUpdateSink => _onUpdateController.sink;
  Stream<MessageSchema> get onUpdateStream => _onUpdateController.stream; // .distinct((prev, next) => prev.msgId == next.msgId)

  MessageStorage _messageStorage = MessageStorage();

  // NO DB NO display
  Future sendMessageReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (tryCount > 3) return;
    try {
      String data = MessageData.getReceipt(received.msgId);
      await chatCommon.sendMessage(received.from, data);
      logger.d("$TAG - sendMessageReceipt - success data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendMessageReceipt - fail - tryCount:$tryCount");
      Future.delayed(Duration(seconds: 1), () {
        sendMessageReceipt(received, tryCount: tryCount++);
      });
    }
  }

  // NO DB NO display
  Future sendMessageContactRequest(ContactSchema? target, String requestType, {int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      DateTime updateAt = DateTime.now();
      String data = MessageData.getContactRequest(requestType, target.profileVersion, updateAt);
      await chatCommon.sendMessage(target.clientAddress, data);
      logger.d("$TAG - sendMessageContactRequest - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendMessageContactRequest - fail - tryCount:$tryCount");
      Future.delayed(Duration(seconds: 1), () {
        sendMessageContactRequest(target, requestType, tryCount: tryCount++);
      });
    }
  }

  // NO DB NO display
  Future sendMessageContactResponse(ContactSchema? target, String requestType, {int tryCount = 1}) async {
    if (contactCommon.currentUser == null || target == null || target.clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      DateTime updateAt = DateTime.now();
      String data;
      if (requestType == RequestType.header) {
        data = MessageData.getContactResponseHeader(contactCommon.currentUser?.profileVersion, updateAt);
      } else {
        data = await MessageData.getContactResponseFull(
          contactCommon.currentUser?.firstName,
          contactCommon.currentUser?.avatar,
          contactCommon.currentUser?.profileVersion,
          updateAt,
        );
      }
      await chatCommon.sendMessage(target.clientAddress, data);
      logger.d("$TAG - sendMessageContactResponse - success - requestType:$requestType - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendMessageContactResponse - fail - requestType:$requestType - tryCount:$tryCount");
      Future.delayed(Duration(seconds: 1), () {
        sendMessageContactResponse(target, requestType, tryCount: tryCount++);
      });
    }
  }

  Future<MessageSchema?> sendMessageText(String? dest, String? content, {bool toast = true}) {
    if (chatCommon.id == null || dest == null || content == null || content.isEmpty) {
      Toast.show(S.of(Global.appContext).failure);
      return Future.value(null);
    }
    MessageSchema schema = MessageSchema.fromSend(
      Uuid().v4(),
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
      Uuid().v4(),
      chatCommon.id!,
      ContentType.image,
      to: dest,
      content: content,
    );
    return sendMessage(schema, await MessageData.getImage(schema));
  }

  Future<MessageSchema?> sendMessage(MessageSchema? schema, String? msgData) async {
    if (schema == null || msgData == null) return null;
    // contact (handle in other entry)
    // topicHandle (handle in other entry)
    // DB
    schema = await _messageStorage.insert(schema);
    if (schema == null) return null;
    // display
    onSavedSink.add(schema);
    // SDK
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
    // pid
    if (pid != null) {
      schema.pid = pid;
      _messageStorage.updatePid(schema.msgId, schema.pid); // await
    }
    // status
    schema = MessageStatus.set(schema, MessageStatus.SendSuccess);
    _messageStorage.updateMessageStatus(schema); // await
    // display
    onUpdateSink.add(schema);
    return schema;
  }
}
