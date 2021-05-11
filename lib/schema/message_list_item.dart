import 'package:equatable/equatable.dart';

import 'contact.dart';
import 'topic.dart';

class MessageListItem extends Equatable {
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

  @override
  List<Object> get props => [targetId];
}
