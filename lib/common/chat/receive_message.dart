import 'dart:async';
import 'dart:io';

import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';

import '../locator.dart';

class ReceiveMessage with Tag {
  ReceiveMessage();

  // ignore: close_sinks
  StreamController<MessageSchema> _onReceiveController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onReceiveSink => _onReceiveController.sink;
  Stream<MessageSchema> get onReceiveStream => _onReceiveController.stream;
  List<StreamSubscription> onReceiveStreamSubscriptions = <StreamSubscription>[];

  // ignore: close_sinks
  StreamController<MessageSchema> _onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => _onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => _onSavedController.stream;

  MessageStorage _messageStorage = MessageStorage();
  TopicStorage _topicStorage = TopicStorage();

  Future onClientMessage(MessageSchema? schema) async {
    if (schema == null) return;
    // contact
    contactHandle(schema); // await
    // topic
    topicHandle(schema); // await
    // receive
    onReceiveSink.add(schema);
  }

  Future contactHandle(MessageSchema received) async {
    if (received.from.isEmpty) return;
    ContactSchema? exist = await contactCommon.queryByClientAddress(received.from);
    if (exist != null) {
      // TODO:GG piece????
      if (received.contentType == ContentType.text || received.contentType == ContentType.textExtension || received.contentType == ContentType.image || received.contentType == ContentType.nknImage || received.contentType == ContentType.audio) {
        if (exist.profileExpiresAt == null || DateTime.now().isAfter(exist.profileExpiresAt!.add(ContactSchema.profileExpireDuration))) {
          logger.d("$TAG - contactHandle - sendMessageContactRequestHeader - schema:$exist");
          await sendMessage.sendMessageContactRequest(exist, RequestType.header);
        } else {
          double between = ((exist.profileExpiresAt?.add(ContactSchema.profileExpireDuration).millisecondsSinceEpoch ?? 0) - DateTime.now().millisecondsSinceEpoch) / 1000;
          logger.d("$TAG contactHandle - expiresAt - between:${between}s");
        }
      }
    } else {
      logger.d("$TAG - contactHandle - new - from:$received.from");
      await contactCommon.addByType(received.from, ContactType.stranger, canDuplicated: true);
    }
  }

  Future topicHandle(MessageSchema received) async {
    if (received.topic == null || received.topic!.isEmpty) return;
    int count = await _topicStorage.queryCountByTopic(received.topic);
    if (count == 0) {
      await _topicStorage.insertTopic(TopicSchema(
        // TODO: get topic info
        // expireAt:
        // joined:
        topic: received.topic!,
      ));
    }
  }

  startReceiveMessage() {
    receiveMessageReceipt();
    receiveMessageContact();
    receiveMessageText();
    receiveMessageMedia();
  }

  Future stopReceiveMessage() {
    List<Future> futures = <Future>[];
    // message
    onReceiveStreamSubscriptions.forEach((StreamSubscription element) {
      futures.add(element.cancel());
    });
    onReceiveStreamSubscriptions.clear();
    return Future.wait(futures);
  }

  // NO DB insert
  receiveMessageReceipt() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.receipt).listen((MessageSchema event) async {
      // update send by receipt TODO:GG piece????
      List<MessageSchema> _schemaList = await _messageStorage.queryList(event.content);
      _schemaList.forEach((MessageSchema element) async {
        element = MessageStatus.set(element, MessageStatus.SendWithReceipt);
        bool updated = await _messageStorage.updateMessageStatus(element);
        if (updated) {
          sendMessage.onUpdateSink.add(element);
        }
      });
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  // NO DB insert
  receiveMessageContact() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.contact).listen((MessageSchema event) async {
      if (event.content == null) return;
      Map<String, dynamic> data = event.content; // == data
      // check
      ContactSchema? exist = await contactCommon.queryByClientAddress(event.from);
      if (exist == null) {
        logger.w("$TAG - receiveMessageContact - empty");
        return;
      }
      String? requestType = data['requestType'];
      String? responseType = data['responseType'];
      String? version = data['version'];
      Map<String, dynamic>? content = data['content'];
      if ((requestType?.isNotEmpty == true) || (requestType == null && responseType == null && version == null)) {
        // need reply (D-Chat NO RequestType.header)
        if (requestType == RequestType.header) {
          await sendMessage.sendMessageContactResponse(exist, RequestType.header);
        } else {
          await sendMessage.sendMessageContactResponse(exist, RequestType.full);
        }
      } else {
        // need save (D-Chat NO RequestType.header)
        if (!contactCommon.isProfileVersionSame(exist.profileVersion, version)) {
          if (responseType != RequestType.full && content == null) {
            await sendMessage.sendMessageContactRequest(exist, RequestType.full);
          } else {
            if (content == null) return;
            String? firstName = content['first_name'] ?? content['name'];
            File? avatar;
            String? avatarType = content['avatar'] != null ? content['avatar']['type'] : null;
            if (avatarType?.isNotEmpty == true) {
              String? avatarData = content['avatar'] != null ? content['avatar']['data'] : null;
              if (avatarData?.isNotEmpty == true) {
                if (avatarData.toString().split(",").length != 1) {
                  avatarData = avatarData.toString().split(",")[1];
                }
                avatar = await FileHelper.convertBase64toFile(avatarData, extension: "jpg");
              }
            }
            contactCommon.setProfile(exist, firstName, avatar?.path, version, notify: true);
            logger.i("$TAG - receiveMessageContact - setProfile - firstName:$firstName - avatar:${avatar?.path} - version:$version");
          }
        } else {
          logger.d("$TAG - receiveMessageContact - profileVersionSame - contact:$exist");
        }
      }
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveMessageText() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) async {
      // duplicated
      List<MessageSchema> exists = await _messageStorage.queryList(event.msgId);
      if (exists.isNotEmpty) {
        logger.d("$TAG - receiveMessageText - duplicated - schema:$exists");
        _checkReceipts(exists); // await
        return;
      }
      // sqlite
      MessageSchema? schema = await _messageStorage.insert(event);
      if (schema == null) return;
      // receipt message
      _checkReceipts([schema]); // await
      // view show
      onSavedSink.add(schema);
      // TODO: notification
      // notification.showDChatNotification();
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveMessageMedia() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.image || event.contentType == ContentType.nknImage).listen((MessageSchema event) async {
      // duplicated
      List<MessageSchema> exists = await _messageStorage.queryList(event.msgId);
      if (exists.isNotEmpty) {
        logger.d("$TAG - receiveMessageMedia - duplicated - schema:$exists");
        _checkReceipts(exists); // await
        return;
      }
      // file
      event.content = await FileHelper.convertBase64toFile(event.content);
      // sqlite
      MessageSchema? schema = await _messageStorage.insert(event);
      if (schema == null) return;
      // receipt message
      _checkReceipts([schema]); // await
      // view show
      onSavedSink.add(schema);
      // TODO: notification
      // notification.showDChatNotification();
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  // receipt(receive) != read(look)
  Future _checkReceipts(List<MessageSchema> schemas) async {
    List<Future> futures = <Future>[];
    schemas.forEach((element) {
      int msgStatus = MessageStatus.get(element);
      if (msgStatus != MessageStatus.ReceivedRead) {
        futures.add(sendMessage.sendMessageReceipt(element));
      }
    });
    return await Future.wait(futures);
  }

  // receipt(receive) != read(look)
  Future<MessageSchema> read(MessageSchema schema) async {
    schema = MessageStatus.set(schema, MessageStatus.ReceivedRead);
    await _messageStorage.updateMessageStatus(schema);
    return schema;
  }
}
