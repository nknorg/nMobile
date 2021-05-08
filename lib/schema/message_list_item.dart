import 'contact.dart';
import 'topic.dart';

class MessageListItem {
  String targetId;
  String sender;
  String content;
  String contentType;
  DateTime lastReceiveTime;
  int notReadCount;
  bool isTop;
  TopicSchema topic;
  ContactSchema contact;

  MessageListItem({
    this.targetId,
    this.sender,
    this.content,
    this.contentType,
    this.lastReceiveTime,
    this.notReadCount,
    this.isTop = false,
  });
}
