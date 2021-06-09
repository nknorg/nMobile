import 'package:equatable/equatable.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/topic.dart';

import 'contact.dart';
import 'topic.dart';

class SessionSchema extends Equatable {
  String targetId;
  String? sender;
  String? contentType;
  String? content;
  DateTime? lastReceiveTime;
  int? notReadCount;

  TopicSchema? topic;
  ContactSchema? contact;
  bool isTop = false;

  SessionSchema({
    required this.targetId,
    this.sender,
    this.contentType,
    this.content,
    this.lastReceiveTime,
    this.notReadCount,
  });

  @override
  List<Object?> get props => [targetId];

  static Future<SessionSchema?> fromMap(Map e) async {
    var res = SessionSchema(
      targetId: e['target_id'] ?? "",
      sender: e['sender'],
      contentType: e['type'],
      content: e['content'],
      lastReceiveTime: DateTime.fromMillisecondsSinceEpoch(e['receive_time']),
      notReadCount: e['not_read'] ?? 0,
    );
    if (res.targetId.isEmpty) return null;
    if (e['topic'] != null) {
      res.topic = await TopicStorage().queryTopicByTopicName(e['topic']);
      res.contact = await ContactStorage().queryByClientAddress(res.targetId);
      res.isTop = res.topic?.isTop ?? false;
    } else {
      res.contact = await ContactStorage().queryByClientAddress(res.targetId);
      res.isTop = res.contact?.isTop ?? false;
    }
    return res;
  }
}
