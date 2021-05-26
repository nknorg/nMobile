import 'dart:async';

import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/message.dart';

import '../locator.dart';

/// Receive messages service
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
  ContactStorage _contactStorage = ContactStorage();

  Future onClientMessage(MessageSchema schema) async {
    if (schema == null) return;
    // contact
    contactHandle(schema.from);
    bool isExists = (await _messageStorage.queryCount(schema.msgId)) > 0;
    if (isExists) return;
    // message
    onReceiveSink.add(schema);
    // sqlite
    await _messageStorage.insertReceivedMessage(schema);
    onSavedSink.add(schema);
  }

  Future contactHandle(String clientAddress) async {
    int count = await _contactStorage.queryCountByClientAddress(clientAddress);
    if (count == 0) {
      await contact.add(ContactSchema(
        type: ContactType.stranger,
        clientAddress: clientAddress,
        // nknWalletAddress: await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress)),
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
    onReceiveStreamSubscriptions?.forEach((StreamSubscription element) {
      futures.add(element?.cancel());
    });
    onSavedStreamSubscriptions?.forEach((StreamSubscription element) {
      futures.add(element?.cancel());
    });
    onReceiveStreamSubscriptions?.clear();
    onSavedStreamSubscriptions?.clear();
    return Future.wait(futures);
  }

  receiveTextMessage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.text).listen((MessageSchema event) {
      // receipt message TODO: batch send receipt message
      chat.sendText(event.from, MessageData.getSendReceipt(event.msgId));
      // TODO: notification
      // notification.showDChatNotification();
    });
    onReceiveStreamSubscriptions.add(subscription);
  }

  receiveReceiptMessage() {
    StreamSubscription subscription = onReceiveStream.where((event) => event.contentType == ContentType.receipt).listen((MessageSchema event) {
      // TODO: batch update receipt message
      _messageStorage.receiveSuccess(event.msgId);
    });
    onReceiveStreamSubscriptions.add(subscription);
  }
}
