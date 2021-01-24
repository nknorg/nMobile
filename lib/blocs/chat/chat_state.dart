
import 'package:nmobile/schemas/message.dart';

abstract class ChatState {
  const ChatState();
}

class NoConnectState extends ChatState {}

class OnConnectState extends ChatState {}

class MessageUpdateState extends ChatState {
  final String target;
  final MessageSchema message;

  const MessageUpdateState({this.target, this.message});
}

class GroupEvicted extends ChatState {
  final String topicName;

  const GroupEvicted(this.topicName);
}

