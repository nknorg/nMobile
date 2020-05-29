import 'package:equatable/equatable.dart';
import 'package:nmobile/schemas/message.dart';


abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class Connect extends ChatEvent {}
class RefreshMessages extends ChatEvent {
  final String target;
  const RefreshMessages({this.target});
}
class ReceiveMessage extends ChatEvent {
  final MessageSchema message;
  const ReceiveMessage(this.message);
}
class SendMessage extends ChatEvent {
  final MessageSchema message;
  const SendMessage(this.message);
}
class GetAndReadMessages extends ChatEvent {
  final String target;
  const GetAndReadMessages({this.target});
}