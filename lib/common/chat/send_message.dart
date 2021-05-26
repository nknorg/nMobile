import 'dart:async';

import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';

import '../locator.dart';

class SendMessage {
  SendMessage();

  // ignore: close_sinks
  StreamController<MessageSchema> _onSendController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSendSink => _onSendController.sink;
  Stream<MessageSchema> get onSendStream => _onSendController.stream; // TODO:GG
  List<StreamSubscription> onSendSubscriptions = <StreamSubscription>[];

  // ignore: close_sinks
  StreamController<MessageSchema> onSavedController = StreamController<MessageSchema>.broadcast();
  StreamSink<MessageSchema> get onSavedSink => onSavedController.sink;
  Stream<MessageSchema> get onSavedStream => onSavedController.stream; // TODO:GG
  List<StreamSubscription> onSavedStreamSubscriptions = <StreamSubscription>[];

  MessageStorage _messageStorage = MessageStorage();
  ContactStorage _contactStorage = ContactStorage();

  sendMessage(MessageSchema schema) async {
    if (schema == null || (schema.to == null && schema.topic == null)) return;
    await chatCommon.sendText(schema.to ?? schema.topic, MessageData.getSendText(schema));
    onSendSink?.add(schema);
  }
}
