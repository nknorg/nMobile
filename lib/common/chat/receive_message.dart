import 'dart:async';

import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/topic.dart';

import '../locator.dart';

class ReceiveMessage {
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
    contactCommon.addByType(schema.from, ContactType.stranger); // wait
    // topic
    topicHandle(schema.topic); // wait
    // receive
    onReceiveSink.add(schema);
  }

  Future topicHandle(String? topic) async {
    if (topic?.isNotEmpty != true) return;
    int count = await _topicStorage.queryCountByTopic(topic);
    if (count == 0) {
      await _topicStorage.insertTopic(TopicSchema(
        // TODO: get topic info
        // expireAt:
        // joined:
        topic: topic!,
      ));
    }
  }

  startReceiveMessage() {
    receiveReceiptMessage();
    receiveTextMessage();
    receiveMediaMessage();
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

  receiveReceiptMessage() {
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
      // NO DB insert
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveTextMessage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) async {
      // sqlite
      MessageSchema? schema = await _messageStorage.insert(event);
      if (schema == null) return;
      // receipt message
      sendMessage.sendMessageReceipt(schema); // wait
      onSavedSink.add(schema);
      // TODO: notification
      // notification.showDChatNotification();
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveMediaMessage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.image).listen((MessageSchema event) async {
      await event.loadMediaFile();
      // sqlite
      MessageSchema? schema = await _messageStorage.insert(event);
      print(schema);
      if (schema == null) return;
      // receipt message
      sendMessage.sendMessageReceipt(schema); // wait
      onSavedSink.add(schema);
      // TODO: notification
      // notification.showDChatNotification();
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  Future<MessageSchema> read(MessageSchema schema) async {
    schema = MessageStatus.set(schema, MessageStatus.ReceivedRead);
    await _messageStorage.updateMessageStatus(schema);
    return schema;
  }
}
