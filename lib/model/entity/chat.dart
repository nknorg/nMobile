import 'package:nmobile/model/entity/topic_repo.dart';
import 'package:nmobile/model/entity/contact.dart';

enum ChatType { PrivateChat, Channel, PrivateChannel }

class ChatSchema {
  ChatType type;
  ContactSchema contact;
  Topic topic;

  ChatSchema({this.type, this.contact, this.topic});
}
