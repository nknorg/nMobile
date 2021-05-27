import 'package:equatable/equatable.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/topic.dart';

import 'contact.dart';
import 'topic.dart';

class SessionSchema extends Equatable {
  String? targetId;
  String? sender;
  String? content;
  String? contentType;
  DateTime? lastReceiveTime;
  int? notReadCount;
  bool isTop = false;
  TopicSchema? topic;
  ContactSchema? contact;

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
  List<Object> get props => [targetId ?? ""];

  static Future<SessionSchema?> fromMap(Map e) async {
    var res = SessionSchema(
      targetId: e['target_id'],
      sender: e['sender'],
      content: e['content'],
      contentType: e['type'],
      lastReceiveTime: DateTime.fromMillisecondsSinceEpoch(e['receive_time']),
      notReadCount: e['not_read'] as int,
    );
    if (res.targetId == null) {
      return null;
    }
    if (e['topic'] != null) {
      res.topic = await TopicStorage().queryTopicByTopicName(res.targetId);
      res.isTop = res.topic?.isTop ?? false;
    } else {
      res.contact = await ContactStorage().queryContactByClientAddress(res.targetId!);
      res.isTop = res.contact?.isTop ?? false;
    }
    return res;
  }
}
