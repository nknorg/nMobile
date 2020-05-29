import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/topic.dart';

enum ChatType { PrivateChat, Channel, PrivateChannel }

class ChatSchema {
  ChatType type;
  ContactSchema contact;
  TopicSchema topic;
  ChatSchema({this.type, this.contact, this.topic});
}