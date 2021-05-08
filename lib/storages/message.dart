import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/message_list_item.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage {
  static String get tableName => 'Messages';

  Database get db => DB.currentDatabase;

  MessageStorage();

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pid TEXT,
        msg_id TEXT,
        sender TEXT,
        receiver TEXT,
        target_id TEXT,
        type TEXT,
        topic TEXT,
        content TEXT,
        options TEXT,
        is_read BOOLEAN,
        is_success BOOLEAN,
        is_outbound BOOLEAN,
        is_send_error BOOLEAN,
        receive_time INTEGER,
        send_time INTEGER,
        delete_time INTEGER
      )''');
    // index
    await db.execute('CREATE INDEX index_messages_pid ON Messages (pid)');
    await db.execute('CREATE INDEX index_messages_msg_id ON Messages (msg_id)');
    await db.execute('CREATE INDEX index_messages_sender ON Messages (sender)');
    await db.execute('CREATE INDEX index_messages_receiver ON Messages (receiver)');
    await db.execute('CREATE INDEX index_messages_target_id ON Messages (target_id)');
    await db.execute('CREATE INDEX index_messages_receive_time ON Messages (receive_time)');
    await db.execute('CREATE INDEX index_messages_send_time ON Messages (send_time)');
    await db.execute('CREATE INDEX index_messages_delete_time ON Messages (delete_time)');
  }

  Future<bool> insertReceivedMessage(MessageSchema schema) async {
    var count = await queryCount(schema.msgId);
    if (count > 0) {
      return false;
    } else {
      Map insertMessageInfo = schema.toEntity();
      int n = await db.insert(tableName, insertMessageInfo);
      if (n > 0) {
        return true;
      }
    }
    return false;
  }

  Future<int> queryCount(String msgId) async {
    var query = await db.query(
      tableName,
      columns: ['COUNT(id)'],
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return Sqflite.firstIntValue(query);
  }

  Future<List<Map>> queryByMsgId(String msgId) async {
    var list = await db.query(
      tableName,
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return list;
  }

  /// message list
  Future<MessageListItem> parseMessageListItem(Map e) async {
    var res = MessageListItem(
      targetId: e['target_id'],
      sender: e['sender'],
      content: e['content'],
      contentType: e['type'],
      lastReceiveTime: DateTime.fromMillisecondsSinceEpoch(e['receive_time']),
      notReadCount: e['not_read'] as int,
    );

    // todo
    // if (e['topic'] != null) {
    //   final repoTopic = TopicRepo();
    //   res.topic = await repoTopic.getTopicByName(e['topic']);
    //   res.contact = await ContactSchema.fetchContactByAddress(res.sender);
    //   res.isTop = res.topic?.isTop ?? false;
    //
    //   if (res.topic == null){
    //     res.isTop = await ContactSchema.getIsTop(res.targetId);
    //     res.contact = await ContactSchema.fetchContactByAddress(res.targetId);
    //   }
    // } else {
    //   if (res.targetId == null){
    //     NLog.w('Wrong!!!!! error msg is___'+e.toString());
    //     return null;
    //   }
    //   res.isTop = await ContactSchema.getIsTop(res.targetId);
    //   res.contact = await ContactSchema.fetchContactByAddress(res.targetId);
    // }
    return res;
  }

  /// ContentType is text, textExtension, media, audio counted to not read
  Future<List<MessageListItem>> getLastMessageList(int skip, int limit) async {
    var res = await db.query(
      '$tableName as m',
      columns: [
        'm.*',
        '(SELECT COUNT(id) from $tableName WHERE target_id = m.target_id AND is_outbound = 0 AND is_read = 0 '
            'AND (type = "text" '
            'or type = "textExtension" '
            'or type = "media" '
            'or type = "audio")) as not_read',
        'MAX(send_time)'
      ],
      where: "type = ? or type = ? or type = ? or type = ? or type = ?",
      whereArgs: [
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.nknImage,
        ContentType.audio,
      ],
      groupBy: 'm.target_id',
      orderBy: 'm.send_time desc',
      limit: limit,
      offset: skip,
    );

    List<MessageListItem> list = <MessageListItem>[];
    for (var i = 0, length = res.length; i < length; i++) {
      var item = res[i];
      MessageListItem model = await parseMessageListItem(item);
      if (model != null) {
        list.add(model);
      }
    }
    if (list.length > 0) {
      return list;
    }
    return null;
  }

  Future<MessageListItem> getUpdateMessageList(String targetId) async {
    var res = await db.query(
      '$tableName',
      where: 'target_id = ? AND is_outbound = 0 AND is_read = 0 AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
      whereArgs: [
        targetId,
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.audio,
        ContentType.nknImage,
      ],
      orderBy: 'send_time desc',
    );

    if (res != null && res.length > 0) {
      Map info = res[0];
      MessageListItem model = await parseMessageListItem(info);
      model.notReadCount = res.length;
      return model;
    } else {
      var countResult = await db.query(
        '$tableName',
        where: 'target_id = ? AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
        whereArgs: [
          targetId,
          ContentType.text,
          ContentType.textExtension,
          ContentType.media,
          ContentType.audio,
          ContentType.nknImage,
        ],
        orderBy: 'send_time desc',
      );
      if (countResult != null && countResult.length > 0) {
        Map info = countResult[0];
        MessageListItem model = await parseMessageListItem(info);
        model.notReadCount = 0;
        return model;
      }
    }
    return null;
  }
}
