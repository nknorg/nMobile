import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:uuid/uuid.dart';

import '../locator.dart';

class SendMessage with Tag {
  // piece
  static const int pieceLength = 1024 * 6;
  static const int piecesParity = 3;
  static const int minPiecesTotal = 2 * piecesParity; // parity >= 2
  static const int maxPiecesTotal = 33 * piecesParity; // parity <= 25

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

  // NO DB NO display (1 to 1)
  Future sendReceipt(MessageSchema received, {int tryCount = 1}) async {
    if (tryCount > 3) return;
    try {
      String data = MessageData.getReceipt(received.msgId);
      await chatCommon.sendMessage(received.from, data);
      logger.d("$TAG - sendReceipt - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendReceipt - fail - tryCount:$tryCount - received:$received");
      await Future.delayed(Duration(seconds: 2), () {
        return sendReceipt(received, tryCount: tryCount++);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendContactRequest(ContactSchema? target, String requestType, {int tryCount = 1}) async {
    if (target == null || target.clientAddress.isEmpty) return;
    if (tryCount > 3) return;
    try {
      DateTime updateAt = DateTime.now();
      String data = MessageData.getContactRequest(requestType, target.profileVersion, updateAt);
      await chatCommon.sendMessage(target.clientAddress, data);
      logger.d("$TAG - sendContactRequest - success - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendContactRequest - fail - tryCount:$tryCount - requestType:$requestType - target:$target");
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactRequest(target, requestType, tryCount: tryCount++);
      });
    }
  }

  // NO DB NO display (1 to 1)
  Future sendContactResponse(ContactSchema? target, String requestType, {int tryCount = 1}) async {
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
      logger.d("$TAG - sendContactResponse - success - requestType:$requestType - data:$data");
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendContactResponse - fail - tryCount:$tryCount - requestType:$requestType");
      await Future.delayed(Duration(seconds: 2), () {
        return sendContactResponse(target, requestType, tryCount: tryCount++);
      });
    }
  }

  // NO DB NO display
  Future<MessageSchema?> sendPiece(MessageSchema schema, {int tryCount = 1}) async {
    if (tryCount > 3) return null;
    try {
      await Future.delayed(Duration(milliseconds: (schema.sendTime ?? DateTime.now()).millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch));
      String data = MessageData.getPiece(schema);
      if (schema.topic != null) {
        OnMessage? onResult = await chatCommon.publishMessage(schema.topic!, data);
        schema.pid = onResult?.messageId;
      } else if (schema.to != null) {
        OnMessage? onResult = await chatCommon.sendMessage(schema.to!, data);
        schema.pid = onResult?.messageId;
      }
      // logger.d("$TAG - sendPiece - success - index:${schema.index} - time:${DateTime.now().millisecondsSinceEpoch} - schema:$schema - data:$data");
      return schema;
    } catch (e) {
      handleError(e);
      logger.w("$TAG - sendPiece - fail - tryCount:$tryCount - schema:$schema");
      return await Future.delayed(Duration(seconds: 2), () {
        return sendPiece(schema, tryCount: tryCount++);
      });
    }
  }

  Future<MessageSchema?> sendText(String? dest, String? content, {bool toast = true}) {
    if (chatCommon.id == null || dest == null || content == null || content.isEmpty) {
      // Toast.show(S.of(Global.appContext).failure);
      return Future.value(null);
    }
    MessageSchema schema = MessageSchema.fromSend(
      Uuid().v4(),
      chatCommon.id!,
      ContentType.text,
      to: dest,
      content: content,
    );
    return _send(schema, MessageData.getText(schema));
  }

  Future<MessageSchema?> sendImage(String? dest, File? content) async {
    if (chatCommon.id == null || dest == null || content == null || (!await content.exists())) {
      // Toast.show(S.of(Global.appContext).failure);
      return null;
    }
    MessageSchema schema = MessageSchema.fromSend(
      Uuid().v4(),
      chatCommon.id!,
      ContentType.media,
      to: dest,
      content: content,
    );
    return _send(schema, await MessageData.getImage(schema));
  }

  Future<MessageSchema?> _send(
    MessageSchema? schema,
    String? msgData, {
    bool database = true,
    bool display = true,
  }) async {
    if (schema == null || msgData == null) return null;
    // contactHandle (handle in other entry)
    // topicHandle (handle in other entry)
    // DB
    if (database) {
      schema = await _messageStorage.insert(schema);
      if (schema == null) return null;
    }
    // display
    if (display) onSavedSink.add(schema);
    // SDK
    Uint8List? pid;
    try {
      pid = await _sendByPiecesIfNeed(schema);
      if (pid == null || pid.isEmpty) {
        if (schema.topic != null) {
          OnMessage? onResult = await chatCommon.publishMessage(schema.topic!, msgData);
          pid = onResult?.messageId;
          logger.d("$TAG - _send - topic - pid:$pid");
        } else if (schema.to != null) {
          OnMessage? onResult = await chatCommon.sendMessage(schema.to!, msgData);
          pid = onResult?.messageId;
          logger.d("$TAG - _send - user - pid:$pid");
        }
      } else {
        logger.d("$TAG - _send - pieces - pid:$pid");
      }
    } catch (e) {
      handleError(e);
      // TODO:GG status_fail
      return null;
    }
    if (pid == null || pid.isEmpty) {
      // TODO:GG status_fail
      return null;
    }
    // pid
    schema.pid = pid;
    if (database) _messageStorage.updatePid(schema.msgId, schema.pid); // await
    // status
    schema = MessageStatus.set(schema, MessageStatus.SendSuccess);
    if (database) _messageStorage.updateMessageStatus(schema); // await
    // display
    if (display) onUpdateSink.add(schema);
    return schema;
  }

  Future<Uint8List?> _sendByPiecesIfNeed(MessageSchema message) async {
    List results = await _convert2Pieces(message);
    if (results.isEmpty) return null;
    String dataBytesString = results[0];
    int bytesLength = results[1];
    int total = results[2];
    int parity = results[3];

    // dataList.size = (total + parity)
    List<Object?>? dataList = await Common.splitPieces(dataBytesString, total, parity);
    if (dataList.isEmpty == true) return null;

    List<Future<MessageSchema?>> futures = <Future<MessageSchema?>>[];
    DateTime dataNow = DateTime.now();
    for (int index = 0; index < dataList.length; index++) {
      Uint8List? data = dataList[index] as Uint8List?;
      if (data == null || data.isEmpty) continue;
      MessageSchema send = MessageSchema.fromSend(
        message.msgId,
        message.from,
        ContentType.piece,
        to: message.to,
        topic: message.topic,
        content: base64Encode(data),
        options: message.options,
        parentType: message.contentType,
        bytesLength: bytesLength,
        total: total,
        parity: parity,
        index: index,
      );
      send.sendTime = dataNow.add(Duration(milliseconds: index * 50)); // wait 50ms
      futures.add(sendPiece(send));
    }
    logger.d("$TAG - _sendByPiecesIfNeed:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
    List<MessageSchema?> returnList = await Future.wait(futures);
    returnList.sort((prev, next) => (prev?.index ?? maxPiecesTotal).compareTo((next?.index ?? maxPiecesTotal)));

    List<MessageSchema?> successList = returnList.where((element) => element != null).toList();
    if (successList.length < total) {
      logger.w("$TAG - _sendByPiecesIfNeed:FAIL - count:${successList.length}");
      return null;
    }
    logger.d("$TAG - _sendByPiecesIfNeed:SUCCESS - count:${successList.length}");

    MessageSchema? firstSuccess = returnList.firstWhere((element) => element?.pid != null);
    return firstSuccess?.pid;
  }

  Future<List<dynamic>> _convert2Pieces(MessageSchema message) async {
    if (!(message.content is File?)) return [];
    File? file = message.content as File?;
    if (file == null || !file.existsSync()) return [];
    int length = await file.length();
    if (length <= pieceLength) return [];
    // data
    Uint8List fileBytes = await file.readAsBytes();
    String base64Data = base64.encode(fileBytes);
    // bytesLength
    int bytesLength = base64Data.length;
    if (bytesLength < pieceLength * minPiecesTotal) return [];
    // total (5~257)
    int total;
    if (bytesLength < pieceLength * maxPiecesTotal) {
      total = bytesLength ~/ pieceLength;
      if (bytesLength % pieceLength > 0) {
        total += 1;
      }
    } else {
      total = maxPiecesTotal;
    }
    // parity(>=2)
    int parity = total ~/ piecesParity;
    if (parity <= 2) {
      parity = 2;
    }
    return [base64Data, bytesLength, total, parity];
  }
}
