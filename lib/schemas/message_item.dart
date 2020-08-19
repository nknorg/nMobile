import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageItem {
  static LOG _log = LOG('MessageItem'.tag());

  String targetId;
  String sender;
  Topic topic;
  String content;
  String contentType;
  DateTime lastReceiveTime;
  int notReadCount;
  bool isTop;

  MessageItem({
    this.targetId,
    this.sender,
    this.content,
    this.topic,
    this.contentType,
    this.lastReceiveTime,
    this.notReadCount,
    this.isTop = false,
  });

  static Future<MessageItem> parseEntity(Future<Database> db, Map e) async {
    var res = MessageItem(
      targetId: e['target_id'],
      sender: e['sender'],
      content: e['content'],
      contentType: e['type'],
      lastReceiveTime: DateTime.fromMillisecondsSinceEpoch(e['receive_time']),
      notReadCount: e['not_read'] as int,
    );
    if (e['topic'] != null) {
      final repoTopic = TopicRepo(db);
      res.topic = await repoTopic.getTopicByName(e['topic']);
      res.isTop = res.topic?.isTop ?? false;
    } else {
      res.isTop = await ContactSchema.getIsTop(db, res.targetId);
    }
    return res;
  }

  static Future<List<MessageItem>> getLastChat(Future<Database> db, {int limit = 20, int offset = 0}) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        '${MessageSchema.tableName} as m',
        columns: [
          'm.*',
          '(SELECT COUNT(id) from ${MessageSchema.tableName} WHERE target_id = m.target_id AND is_outbound = 0 AND is_read = 0) as not_read',
          'MAX(send_time)'
        ],
        where: "type = ? or type = ? or type = ? or type = ? or type = ?",
        whereArgs: [ContentType.text, ContentType.textExtension, ContentType.media, ContentType.ChannelInvitation, ContentType.eventSubscribe],
        //ContentType.ChannelInvitation
        groupBy: 'm.target_id',
        orderBy: 'm.send_time desc',
        limit: limit,
        offset: offset,
      );
      List<MessageItem> list = <MessageItem>[];
      for (var i = 0, length = res.length; i < length; i++) {
        var item = res[i];
        list.add(await MessageItem.parseEntity(db, item));
      }
      return list;
    } catch (e) {
      _log.e('getLastChat', e);
    }
  }

  static Future<MessageItem> getTargetChat(Future<Database> db, String targetId) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        '${MessageSchema.tableName} as m',
        columns: ['m.*', '(SELECT COUNT(id) from ${MessageSchema.tableName} WHERE sender = m.target_id AND is_read = 0) as not_read', 'MAX(send_time)'],
        groupBy: 'm.target_id',
        having: 'm.target_id = \'$targetId\'',
        orderBy: 'm.send_time desc',
      );

      if (res != null && res.length > 0) {
        return await MessageItem.parseEntity(db, res.first);
      } else {
        return null;
      }
    } catch (e) {
      _log.e('getTargetChat', e);
    }
  }

  static Future<int> deleteTargetChat(Future<Database> db, String targetId) async {
    // Returns the number of changes made
    return await (await db).delete(MessageSchema.tableName, where: 'target_id = ?', whereArgs: [targetId]);
  }
}
