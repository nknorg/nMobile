import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/schemas/contact.dart';

enum ChatType { PrivateChat, Channel, PrivateChannel }

class ChatSchema {
  ChatType type;
  ContactSchema contact;
  Topic topic;

  ChatSchema({this.type, this.contact, this.topic});
}
