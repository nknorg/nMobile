import 'package:nmobile/schemas/message.dart';

abstract class ChatState {
  const ChatState();
}
class NotConnect extends ChatState {}
class Connected extends ChatState {}
class MessagesUpdated extends ChatState {
  final String target;
  final MessageSchema message;
  const MessagesUpdated({this.target, this.message});
}
