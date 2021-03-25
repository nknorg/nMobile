import 'package:nmobile/model/entity/message.dart';

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

class UpdateChatMessageState extends ChatState {
  final List<MessageSchema> messageList;
  const UpdateChatMessageState(this.messageList);
}

class GroupEvicted extends ChatState {
  final String topicName;

  const GroupEvicted(this.topicName);
}
