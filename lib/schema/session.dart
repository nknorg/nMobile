import 'package:equatable/equatable.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/topic.dart';

import 'contact.dart';
import 'topic.dart';

class SessionSchema extends Equatable {
  String targetId;
  String sender;
  String content;
  String contentType;
  DateTime lastReceiveTime;
  int notReadCount;
  bool isTop;
  TopicSchema topic;
  ContactSchema contact;

  SessionSchema({
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

  static Future<SessionSchema> fromMap(Map e) async {
    var res = SessionSchema(
      targetId: e['target_id'],
      sender: e['sender'],
      content: e['content'],
      contentType: e['type'],
      lastReceiveTime: DateTime.fromMillisecondsSinceEpoch(e['receive_time']),
      notReadCount: e['not_read'] as int,
    );

    // todo
    if (e['topic'] != null) {
      res.contact = await ContactStorage().queryContactByClientAddress(res.targetId);
      res.isTop = res.contact?.isTop ?? false;
      res.topic = await TopicStorage().queryTopicByTopicName(e['topic']);
      // final repoTopic = TopicRepo();
      // res.topic = await repoTopic.getTopicByName(e['topic']);

      //
      // if (res.topic == null){
      //   res.isTop = await ContactSchema.getIsTop(res.targetId);
      //   res.contact = await ContactSchema.fetchContactByAddress(res.targetId);
      // }
    } else {
      if (res.targetId == null) {
        return null;
      }

      res.contact = await ContactStorage().queryContactByClientAddress(res.targetId);
      res.isTop = res.contact?.isTop ?? false;
    }
    return res;
  }
}
