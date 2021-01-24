import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class NKNChatOnMessageEvent extends ChatEvent {}

class RefreshMessageListEvent extends ChatEvent {
  final String target;
  const RefreshMessageListEvent({this.target});
}

class RefreshMessageChatEvent extends ChatEvent {
  final MessageSchema message;
  const RefreshMessageChatEvent(this.message);
}

class ReceiveMessageEvent extends ChatEvent {
  final MessageSchema message;
  const ReceiveMessageEvent(this.message);
}

class SendMessageEvent extends ChatEvent {
  final MessageSchema message;
  const SendMessageEvent(this.message);
}

class UpdateMessageEvent extends ChatEvent {
  final MessageSchema message;
  const UpdateMessageEvent(this.message);
}

class GetAndReadMessages extends ChatEvent {
  final String target;

  const GetAndReadMessages({this.target});
}
