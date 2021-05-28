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
  List<StreamSubscription> onSavedStreamSubscriptions = <StreamSubscription>[];

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
    receiveTextMessage();
    receiveReceiptMessage();
  }

  Future stopReceiveMessage() {
    List<Future> futures = <Future>[];
    // message
    onReceiveStreamSubscriptions.forEach((StreamSubscription element) {
      futures.add(element.cancel());
    });
    onSavedStreamSubscriptions.forEach((StreamSubscription element) {
      futures.add(element.cancel());
    });
    onReceiveStreamSubscriptions.clear();
    onSavedStreamSubscriptions.clear();
    return Future.wait(futures);
  }

  receiveTextMessage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) async {
      // sqlite
      MessageSchema? schema = await _messageStorage.insert(event);
      if (schema == null) return;
      // receipt message
      sendMessage.sendReceipt(event); // wait
      onSavedSink.add(schema);
      // TODO: notification
      // notification.showDChatNotification();
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveReceiptMessage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.receipt).listen((MessageSchema event) {
      // update send by receipt
      _messageStorage.updateByMessageStatus(event.content, MessageStatus.SendByReplyReceipt); // wait
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  Future<bool> read(MessageSchema schema) {
    return _messageStorage.updateByMessageStatus(schema.msgId, MessageStatus.ReceivedRead);
  }
}
