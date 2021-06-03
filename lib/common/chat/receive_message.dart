import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nmobile/common/chat/send_message.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

import '../global.dart';
import '../locator.dart';

class ReceiveMessage with Tag {
  ReceiveMessage();

  // ignore: close_sinks
  StreamController<MessageSchema> _onReceiveController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onReceiveSink => _onReceiveController.sink;
  Stream<MessageSchema> get onReceiveStream => _onReceiveController.stream.distinct((prev, next) => prev.pid == next.pid);
  List<StreamSubscription> onReceiveStreamSubscriptions = <StreamSubscription>[];

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream.distinct((prev, next) => prev.pid == next.pid);

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  startReceive() {
    receiveReceipt();
    receiveContact();
    receivePiece();
    receiveText();
    receiveImage();
  }

  Future stopReceive() {
    List<Future> futures = <Future>[];
    onReceiveStreamSubscriptions.forEach((StreamSubscription element) {
      futures.add(element.cancel());
    });
    onReceiveStreamSubscriptions.clear();
    return Future.wait(futures);
  }

  Future onClientMessage(MessageSchema? message) async {
    if (message == null) return;
    // contact
    ContactSchema? contactSchema = await contactHandle(message);
    // topic
    TopicSchema? topicSchema = await topicHandle(message);
    // notification
    notificationHandle(contactSchema, topicSchema, message);

    // receive
    onReceiveSink.add(message);
  }

  Future<ContactSchema?> contactHandle(MessageSchema received) async {
    // type TODO:GG piece????
    bool noText = received.contentType != ContentType.text && received.contentType != ContentType.textExtension;
    bool noImage = received.contentType != ContentType.media && received.contentType != ContentType.nknImage;
    bool noAudio = received.contentType != ContentType.audio;
    if (noText && noImage && noAudio) return null;
    // duplicated
    if (received.from.isEmpty) return null;
    ContactSchema? exist = await contactCommon.queryByClientAddress(received.from);
    if (exist == null) {
      logger.d("$TAG - contactHandle - new - from:$received.from");
      return await contactCommon.addByType(received.from, ContactType.stranger, canDuplicated: true);
    } else {
      if (exist.profileExpiresAt == null || DateTime.now().isAfter(exist.profileExpiresAt!.add(Settings.profileExpireDuration))) {
        logger.d("$TAG - contactHandle - sendMessageContactRequestHeader - schema:$exist");
        await sendMessage.sendContactRequest(exist, RequestType.header);
      } else {
        double between = ((exist.profileExpiresAt?.add(Settings.profileExpireDuration).millisecondsSinceEpoch ?? 0) - DateTime.now().millisecondsSinceEpoch) / 1000;
        logger.d("$TAG contactHandle - expiresAt - between:${between}s");
      }
    }
    return exist;
  }

  Future<TopicSchema?> topicHandle(MessageSchema received) async {
    if (received.topic == null || received.topic!.isEmpty) return null;
    TopicSchema? topicSchema = await _topicStorage.queryTopicByTopicName(received.topic);
    if (topicSchema == null) {
      return await _topicStorage.insertTopic(TopicSchema(
        // TODO: get topic info
        // expireAt:
        // joined:
        topic: received.topic!,
      ));
    }
    return topicSchema;
  }

  Future<void> notificationHandle(ContactSchema? contact, TopicSchema? topic, MessageSchema message) async {
    late String title;
    late String content;
    if (contact != null && topic == null) {
      title = contact.displayName;
      content = message.content;
    } else if (topic != null) {
      notification.showDChatNotification('[${topic.topicShort}] ${contact?.displayName}', message.content);
      title = '[${topic.topicShort}] ${contact?.displayName}';
      content = message.content;
    }

    S localizations = S.of(Global.appContext);
    // TODO: notification
    switch (message.contentType) {
      case ContentType.text:
      case ContentType.textExtension:
        notification.showDChatNotification(title, content);
        break;
      case ContentType.media:
      case ContentType.nknImage: // TODO: remove
        notification.showDChatNotification(title, '[${localizations.image}]');
        break;
      case ContentType.audio:
        notification.showDChatNotification(title, '[${localizations.audio}]');
        break;
    }
  }

  // NO DB NO display
  receiveReceipt() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.receipt).listen((MessageSchema event) async {
      List<MessageSchema> _schemaList = await _messageStorage.queryList(event.content);
      _schemaList.forEach((MessageSchema element) async {
        element = MessageStatus.set(element, MessageStatus.SendWithReceipt);
        bool updated = await _messageStorage.updateMessageStatus(element);
        if (updated) {
          // update send by receipt
          sendMessage.onUpdateSink.add(element);
        }
        logger.d("$TAG - receiveReceipt - updated:$element");
      });
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  // NO DB NO display
  receiveContact() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.contact).listen((MessageSchema event) async {
      if (event.content == null) return;
      Map<String, dynamic> data = event.content; // == data
      // duplicated
      ContactSchema? exist = await contactCommon.queryByClientAddress(event.from);
      if (exist == null) {
        logger.w("$TAG - receiveContact - empty - data:$data");
        return;
      }
      // D-Chat NO RequestType.header
      String? requestType = data['requestType'];
      String? responseType = data['responseType'];
      String? version = data['version'];
      Map<String, dynamic>? content = data['content'];
      if ((requestType?.isNotEmpty == true) || (requestType == null && responseType == null && version == null)) {
        // need reply
        if (requestType == RequestType.header) {
          await sendMessage.sendContactResponse(exist, RequestType.header);
        } else {
          await sendMessage.sendContactResponse(exist, RequestType.full);
        }
      } else {
        // need request/save
        if (!contactCommon.isProfileVersionSame(exist.profileVersion, version)) {
          if (responseType != RequestType.full && content == null) {
            await sendMessage.sendContactRequest(exist, RequestType.full);
          } else {
            if (content == null) {
              logger.w("$TAG - receiveContact - content is empty - data:$data");
              return;
            }
            String? firstName = content['first_name'] ?? content['name'];
            File? avatar;
            String? avatarType = content['avatar'] != null ? content['avatar']['type'] : null;
            if (avatarType?.isNotEmpty == true) {
              String? avatarData = content['avatar'] != null ? content['avatar']['data'] : null;
              if (avatarData?.isNotEmpty == true) {
                if (avatarData.toString().split(",").length != 1) {
                  avatarData = avatarData.toString().split(",")[1];
                }
                avatar = await FileHelper.convertBase64toFile(avatarData, SubDirType.contact, extension: "jpg");
              }
            }
            contactCommon.setProfile(exist, firstName, avatar?.path, version, notify: true);
            logger.i("$TAG - receiveContact - setProfile - firstName:$firstName - avatar:${avatar?.path} - version:$version - data:$data");
          }
        } else {
          logger.d("$TAG - receiveContact - profileVersionSame - contact:$exist - data:$data");
        }
      }
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receivePiece() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.piece).listen((MessageSchema event) async {
      // duplicated
      List<MessageSchema> existsCombine = await _messageStorage.queryListByType(event.msgId, event.parentType);
      if (existsCombine.isNotEmpty) {
        logger.d("$TAG - receivePiece - duplicated - schema:$existsCombine");
        _checkReceipt(existsCombine[0]); // await
        return;
      }
      // piece
      MessageSchema? piece = await _messageStorage.queryByPid(event.pid);
      if (piece == null) {
        event.content = FileHelper.convertBase64toFile(event.content, SubDirType.cache, extension: event.parentType);
        piece = await _messageStorage.insert(event);
      }
      if (piece == null) return;
      // pieces
      int total = piece.total ?? SendMessage.maxPiecesTotal;
      int parity = piece.parity ?? (total ~/ SendMessage.piecesParity);
      int bytesLength = piece.bytesLength ?? 0;
      List<MessageSchema> pieces = await _messageStorage.queryListByType(piece.msgId, piece.contentType);
      if (pieces.isEmpty || pieces.length < total || bytesLength <= 0) {
        logger.d("$TAG - receivePiece - progress:${pieces.length}/${piece.total}");
        return;
      }
      pieces.sort((prev, next) => (prev.index ?? SendMessage.maxPiecesTotal).compareTo((next.index ?? SendMessage.maxPiecesTotal)));
      // combine
      logger.d("$TAG - receivePiece - COMBINE:START - total:$total - parity:$parity - bytesLength:${formatFlowSize(bytesLength.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}");
      List<Uint8List> recoverList = <Uint8List>[];
      for (int index = 0; index < pieces.length; index++) {
        MessageSchema item = pieces[index];
        File? file = item.content as File?;
        if (file == null) continue;
        Uint8List itemBytes = file.readAsBytesSync();
        recoverList.add(itemBytes);
      }
      if (recoverList.length < total) {
        logger.w("$TAG - receivePiece - COMBINE:FAIL - recover_lost:${pieces.length - recoverList.length}");
        return;
      }
      String? base64String = await Common.combinePieces(recoverList, total, parity, bytesLength);
      if (base64String == null || base64String.isEmpty) {
        logger.w("$TAG - receivePiece - COMBINE:FAIL - base64String is empty");
        return;
      }
      MessageSchema combine = MessageSchema.fromPieces(pieces, base64String);
      logger.d("$TAG - receivePiece - COMBINE:SUCCESS - combine:$combine");
      onClientMessage(combine);
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveText() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) async {
      // duplicated
      MessageSchema? exists = await _messageStorage.queryByPid(event.pid);
      if (exists != null) {
        logger.d("$TAG - receiveText - duplicated - schema:$exists");
        _checkReceipt(exists); // await
        return;
      }
      // DB
      MessageSchema? schema = await _messageStorage.insert(event);
      if (schema == null) return;
      // receipt
      _checkReceipt(schema); // await
      // display
      onSavedSink.add(schema);
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveImage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.image || event.contentType == ContentType.nknImage).listen((MessageSchema event) async {
      // duplicated
      MessageSchema? exists = await _messageStorage.queryByPid(event.pid);
      if (exists != null) {
        logger.d("$TAG - receiveImage - duplicated - schema:$exists");
        _checkReceipt(exists); // await
        return;
      }
      // File
      event.content = await FileHelper.convertBase64toFile(event.content, SubDirType.chat, extension: "jpg");
      // DB
      MessageSchema? schema = await _messageStorage.insert(event);
      if (schema == null) return;
      // receipt
      _checkReceipt(schema); // await
      // display
      onSavedSink.add(schema);
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  // receipt(receive) != read(look)
  Future _checkReceipt(MessageSchema schema) async {
    int msgStatus = MessageStatus.get(schema);
    if (msgStatus != MessageStatus.ReceivedRead) {
      await sendMessage.sendReceipt(schema);
    }
  }

  // receipt(receive) != read(look)
  Future<MessageSchema> read(MessageSchema schema) async {
    schema = MessageStatus.set(schema, MessageStatus.ReceivedRead);
    await _messageStorage.updateMessageStatus(schema);
    return schema;
  }
}
