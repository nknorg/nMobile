import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/permission.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class TopicType {
  static const String private = 'private';
  static const String public = 'public';
}

class TopicSchema {
  int id;
  String topic;
  int count;
  File avatar;
  String type;
  String owner;
  Map<String, dynamic> data;
  DateTime expiresAt;
  DateTime updateTime;
  OptionsSchema options;

  TopicSchema({
    this.id,
    this.topic,
    this.count,
    this.avatar,
    this.type,
    this.owner,
    this.data,
    this.expiresAt,
    this.updateTime,
  }) {
    if (isPrivateTopic(topic)) {
      type = TopicType.private;
    } else {
      type = TopicType.public;
    }

    if (type == TopicType.private) {
      int index = topic.lastIndexOf('.');
      owner = topic.substring(index + 1);
    }
  }

  String get topicName {
    if (isPrivateTopic(topic)) {
      int index = topic.lastIndexOf('.');
      return topic.substring(0, index);
    }
    return topic;
  }

  String get subTitle {
    try {
      if (isPrivateTopic(topic)) {
        return topicName + '.' + owner.substring(0, 8);
      } else {
        return topic;
      }
    } catch (e) {
      return topic;
    }
  }

  Widget avatarWidget(
    FutureOr<Database> db, {
    Color backgroundColor,
    double size,
    Color fontColor,
    Widget bottomRight,
  }) {
    LabelType fontType = LabelType.h4;
    if (size > 60) {
      fontType = LabelType.h1;
    } else if (size > 50) {
      fontType = LabelType.h2;
    } else if (size > 40) {
      fontType = LabelType.h3;
    } else if (size > 30) {
      fontType = LabelType.h4;
    }
    if (avatar == null) {
      var wid = <Widget>[
        Material(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          color: Color(getOptions(db).backgroundColor),
          child: Container(
            alignment: Alignment.center,
            width: size,
            height: size,
            child: Label(
              topic.substring(0, 2).toUpperCase(),
              type: fontType,
              color: Color(getOptions(db).color),
            ),
          ),
        ),
      ];

      if (bottomRight != null) {
        wid.add(
          Positioned(
            bottom: 0,
            right: 0,
            child: bottomRight,
          ),
        );
      }

      return Stack(
        children: wid,
      );
    } else {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: Container(
            decoration: BoxDecoration(image: DecorationImage(image: FileImage(avatar))),
          ),
        ),
      );
    }
  }

  Future<bool> setAvatar(Database db, String accountPubkey, File image) async {
    avatar = image;
    Map<String, dynamic> data = {
      'avatar': getLocalContactPath(accountPubkey, image.path),
//      'avatar': getLocalPath(image.path),
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };

    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
        TopicSchema.tableName,
        columns: ['*'],
        where: 'id = ?',
        whereArgs: [id],
      );
      var record = res?.first;

      if (record['avatar'] != null) {
        var file = File(join(Global.applicationRootDirectory.path, record['avatar']));

        if (file.existsSync()) {
          file.delete();
        }
      }

      var count = await db.update(
        TopicSchema.tableName,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      return count > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  bool isOwner(String accountPubkey) {
    return accountPubkey == owner;
  }

  static Future<String> subscribe(DChatAccount account, {
    String identifier = '',
    String topic,
    int duration = 400000,
    String fee = '0',
    String meta = '',
  }) async {
    LocalStorage.removeTopicFromUnsubscribeList(account.client.pubkey, topic);
    Global.removeTopicCache(topic);
    String topicHash = genChannelId(topic);
    try {
      var hash = await account.client.subscribe(topicHash: topicHash, identifier: identifier, duration: duration, fee: fee, meta: meta);

      return hash;
    } catch (e) {
      if (e != null && e is String) {
        return subscribe(account, topic: topicHash, identifier: identifier, duration: duration, fee: fee, meta: meta);
      }
      if (e != null && e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
        showToast(NMobileLocalizations.of(Global.appContext).password_wrong);
      } else {
        return subscribe(account, topic: topicHash, identifier: identifier, duration: duration, fee: fee, meta: meta);
      }
    }
  }

  Future<Map<String, dynamic>> getPrivateOwnerMetaAction(DChatAccount account) async {
    String topicHash = genChannelId(topic);
    int i = 0;
    Map<String, dynamic> resultMeta = Map<String, dynamic>();
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');
      NLog.d(res);
      if (res['meta'] == null || (res['meta'] as String).isEmpty) {
        break;
      }
      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }
      if (meta['accept'] != null) {
        List resultMetaAccept = (resultMeta['accept'] as List);
        if (resultMetaAccept == null) {
          resultMetaAccept = [];
        }
        if (meta['accept'] is List) {
          resultMetaAccept.addAll(meta['accept']);
        }
        resultMeta['accept'] = resultMetaAccept;
      }
      if (meta['reject'] != null) {
        List resultMetaReject = (resultMeta['reject'] as List);
        if (resultMetaReject == null) {
          resultMetaReject = [];
        }
        if (meta['reject'] is List) {
          resultMetaReject.addAll(meta['reject']);
        }

        resultMeta['reject'] = resultMetaReject;
      }
      i++;
    }
    TopicSchema topicSchema = await TopicSchema.getTopic(account.dbHolder.db, topic);
    if (topicSchema == null) {
      topicSchema = TopicSchema(topic: topic);
    }
    topicSchema.data = resultMeta;
    NLog.d('$topic  $resultMeta');
    topicSchema.insertOrUpdate(account.dbHolder.db, account.client.pubkey);
    return resultMeta;
  }

  Future<Map<String, dynamic>> getPrivateOwnerMeta(DChatAccount account, {cache: true}) async {
    TopicSchema topicSchema = await getTopic(account.dbHolder.db, topic);
    if (topicSchema != null && topicSchema.data != null && topicSchema.data.length > 0 && cache) {
      NLog.d('use cache meta data');
      return topicSchema.data;
    } else {
      return getPrivateOwnerMetaAction(account);
    }
  }

  Future<String> acceptPrivateMember(DChatAccount account, {
    int duration = 400000,
    String fee = '0',
    String addr,
  }) async {
    Global.removeTopicCache(topic);
    String topicHash = genChannelId(topic);
    int i = 0;
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');

      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }

      if (meta == null || meta.keys.length == 0) {
        meta['accept'] = [
          {'addr': addr}
        ];
      } else {
        if (res['meta'].toString().length >= 950) {
          i++;
          continue;
        }

        var x = (meta['accept'] as List).firstWhere((x) => x['addr'] == addr, orElse: () => null);
        if (x == null) {
          (meta['accept'] as List).add({'addr': addr});
        }
      }

      String hash = await TopicSchema.subscribe(
        account,
        identifier: '__${i.toString()}__.__permission__',
        topic: topic,
        meta: jsonEncode(meta),
        duration: duration,
        fee: fee,
      );
      NLog.d('meta: ${jsonEncode(meta)}', tag: 'acceptPrivateMember');
      NLog.d('hash: $hash', tag: 'acceptPrivateMember');
      return hash;
    }
  }

  Future<String> removeAcceptPrivateMember(DChatAccount account, {
    int duration = 400000,
    String fee = '0',
    String addr,
  }) async {
    String topicHash = genChannelId(topic);
    int i = 0;
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');

      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }

      if (meta == null || meta.keys.length == 0) {
        return null;
      } else {
        int index = (meta['accept'] as List).indexWhere((x) {
          return x['addr'] == addr;
        });
        if (index < 0) {
          i++;
          continue;
        }
        (meta['accept'] as List).removeWhere((x) => x['addr'] == addr);
      }

      String hash = await TopicSchema.subscribe(
        account,
        identifier: '__${i.toString()}__.__permission__',
        topic: topic,
        meta: jsonEncode(meta),
        duration: duration,
        fee: fee,
      );
      NLog.d('meta: ${jsonEncode(meta)}', tag: 'removeAcceptPrivateMember');
      NLog.d('hash: $hash', tag: 'removeAcceptPrivateMember');
      return hash;
    }
  }

  /// remove from private group  1.remove from accept 2. join reject
  Future<String> joinRejectPrivateMember(DChatAccount account, {
    int duration = 400000,
    String fee = '0',
    String addr,
  }) async {
    Global.removeTopicCache(topic);
    String topicHash = genChannelId(topic);
    int i = 0;
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');
      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }

      if (meta == null || meta.keys.length == 0) {
        return null;
      } else {
        int index = (meta['accept'] as List).indexWhere((x) {
          return x['addr'] == addr;
        });
        if (index < 0) {
          i++;
          continue;
        }
        (meta['accept'] as List).removeWhere((x) => x['addr'] == addr);
      }

      String hash = await TopicSchema.subscribe(
        account,
        identifier: '__${i.toString()}__.__permission__',
        topic: topic,
        meta: jsonEncode(meta),
        duration: duration,
        fee: fee,
      );
      NLog.d('meta: ${jsonEncode(meta)}', tag: 'removeAcceptPrivateMember');
      NLog.d('hash: $hash', tag: 'removeAcceptPrivateMember');
      return hash;
    }
  }

  Future<String> rejectPrivateMember(DChatAccount account, {
    int duration = 400000,
    String fee = '0',
    String addr,
  }) async {
    Global.removeTopicCache(topic);
    String topicHash = genChannelId(topic);
    int i = 0;
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');

      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }

      if (meta == null || meta.keys.length == 0) {
        meta['reject'] = [
          {'addr': addr}
        ];
      } else {
        if (res['meta'].toString().length >= 950) {
          i++;
          continue;
        }
        if (meta['reject'] is List) {
          (meta['reject'] as List).add({'addr': addr});
        } else {
          meta['reject'] = [
            {'addr': addr}
          ];
        }
      }

      String hash = await TopicSchema.subscribe(
        account,
        identifier: '__${i.toString()}__.__permission__',
        topic: topic,
        meta: jsonEncode(meta),
        duration: duration,
        fee: fee,
      );
      NLog.d('meta: ${jsonEncode(meta)}', tag: 'rejectPrivateMember');
      NLog.d('hash: $hash', tag: 'rejectPrivateMember');
      return hash;
    }
  }

  Future<String> removeRejectPrivateMember(DChatAccount account, {
    int duration = 400000,
    String fee = '0',
    String addr,
  }) async {
    Global.removeTopicCache(topic);
    String topicHash = genChannelId(topic);
    int i = 0;
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');

      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }

      if (meta == null || meta.keys.length == 0) {
        return null;
      } else {
        int index = (meta['reject'] as List).indexWhere((x) {
          return x['addr'] == addr;
        });
        if (index < 0) {
          i++;
          continue;
        }
        (meta['reject'] as List).removeWhere((x) => x['addr'] == addr);
      }

      String hash = await TopicSchema.subscribe(
        account,
        identifier: '__${i.toString()}__.__permission__',
        topic: topic,
        meta: jsonEncode(meta),
        duration: duration,
        fee: fee,
      );
      NLog.d('meta: ${jsonEncode(meta)}', tag: 'removeRejectPrivateMember');
      NLog.d('hash: $hash', tag: 'removeRejectPrivateMember');
      return hash;
    }
  }

  static String get tableName => 'Topic';

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE Topic (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        count INTEGER,
        avatar TEXT,
        type TEXT,
        owner TEXT,
        data TEXT,
        expires_at INTEGER,
        updated_time INTEGER,
        options TEXT
      )''');
    // index
    await db.execute('CREATE INDEX topic_index_topic ON Topic (topic)');
    await db.execute('CREATE INDEX topic_index_count ON Topic (count)');
    await db.execute('CREATE INDEX topic_index_owner ON Topic (owner)');
    await db.execute('CREATE INDEX topic_index_expires_at ON Topic (expires_at)');
    await db.execute('CREATE INDEX topic_index_update_time ON Topic (updated_time)');
  }

  toEntity(String accountPubkey) {
    DateTime now = DateTime.now();
    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'count': count,
      'avatar': avatar != null ? getLocalContactPath(accountPubkey, avatar.path) : null,
//      'avatar': avatar != null ? getLocalPath(avatar.path) : null,
      'type': type,
      'owner': owner,
      'options': options?.toJson(),
      'data': data != null ? jsonEncode(data) : '{}',
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'updated_time': updateTime?.millisecondsSinceEpoch,
    };

    return map;
  }

  static TopicSchema parseEntity(Map e) {
    var res = TopicSchema(
      id: e['id'],
      topic: e['topic'],
      count: e['count'],
      avatar: e['avatar'] != null ? File(join(Global.applicationRootDirectory.path, e['avatar'])) : null,
      type: e['type'],
      owner: e['owner'],
      expiresAt: e['expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['expires_at']) : null,
      updateTime: e['updated_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['updated_time']) : null,
    );

    if (e['data'] != null) {
      try {
        res.data = jsonDecode(e['data']);
      } on FormatException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
      }
    }
    if (e['options'] != null) {
      try {
        Map<String, dynamic> map = jsonDecode(e['options']);
        res.options = OptionsSchema(backgroundColor: map['backgroundColor'], color: map['color']);
      } on FormatException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
        res.options = OptionsSchema();
      }
    }
    return res;
  }

  Future<bool> insert(Database db, String accountPubkey) async {
    if (updateTime == null) updateTime = DateTime.now();
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      int n = await db.insert(TopicSchema.tableName, toEntity(accountPubkey));
      return n > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
      return false;
    }
  }

  Future<bool> insertIfNoData(Future<Database> db, String accountPubkey) async {
    if (updateTime == null) updateTime = DateTime.now();
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var countQuery = await (await db).query(
        TopicSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      var count = countQuery != null ? Sqflite.firstIntValue(countQuery) : 0;
      if (count == 0) {
        int n = await (await db).insert(TopicSchema.tableName, toEntity(accountPubkey));
        return n > 0;
      }
      return false;
    } catch (e) {
      LogUtil.e('insertOrUpdate', tag: 'SqliteStorage');
      return false;
    }
  }

  OptionsSchema getOptions(FutureOr<Database> db) {
    int random = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
    int backgroundColor = DefaultTheme.headerBackgroundColor[random];
    int color = DefaultTheme.headerColor[random];
    if (options == null || options.backgroundColor == null || options.color == null) {
      setOptionColor(db, backgroundColor, color);
    }
    return options;
  }

  Future<bool> setOptionColor(FutureOr<Database> db, int backgroundColor, int color) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      if (options == null) options = OptionsSchema();
      options.backgroundColor = backgroundColor;
      options.color = color;
      NLog.d(options.toJson());
      var count = await (await db).update(
        TopicSchema.tableName,
        {
          'options': options.toJson(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<bool> insertOrUpdate(Future<Database> db, String accountPubkey) async {
    if (updateTime == null) updateTime = DateTime.now();
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var countQuery = await (await db).query(
        TopicSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      var count = countQuery != null ? Sqflite.firstIntValue(countQuery) : 0;
      if (count == 0) {
        int n = await (await db).insert(TopicSchema.tableName, toEntity(accountPubkey));
        return n > 0;
      } else {
        updateTime = DateTime.now();

        int n = await (await db).update(
          TopicSchema.tableName,
          {
            'type': type,
            'data': data != null ? jsonEncode(data) : null,
            'owner': owner,
            'updated_time': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'topic = ?',
          whereArgs: [topic],
        );
        return n > 0;
      }
    } catch (e) {
      LogUtil.e('insertOrUpdate', tag: 'SqliteStorages');
      return false;
    }
  }

  static Future<TopicSchema> getTopic(Future<Database> db, String topic) async {
    if (topic == null || topic.isEmpty) {
      return null;
    }
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        TopicSchema.tableName,
        columns: ['*'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      return TopicSchema.parseEntity(res?.first);
    } catch (e) {
      NLog.e(e);
      return null;
    }
  }

  static Future<List<TopicSchema>> getAllTopic(Future<Database> db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await (await db).query(
        TopicSchema.tableName,
        columns: ['*'],
      );

      return res.map((x) => parseEntity(x)).toList();
    } catch (e) {
      NLog.e(e);
      return null;
    }
  }

  Future<int> getTopicCount(DChatAccount account) async {
    try {
      await getSubscribers(account);
      Database db = await account.dbHolder.db;
      var countQuery = await db.query(
        SubscribersSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      count = countQuery != null ? Sqflite.firstIntValue(countQuery) : 0;

      db.update(
        TopicSchema.tableName,
        {
          'count': count,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return count;
    } catch (e) {
      NLog.d(e);
      // fixme by chenai on 07/07/2020: Are you joke me???
      return getTopicCount(account);
    }
  }

  Future<void> unsubscribe(DChatAccount account, {int c = 0}) async {
    int count = c;
    try {
      Global.removeTopicCache(topic);
      LocalStorage.saveUnsubscribeTopic(account.client.pubkey, topic);
      String topicHash = genChannelId(topic);
      var hash = await account.client.unsubscribe(topicHash: topicHash);
      if (hash != null) {
//        Database db = SqliteStorage(db: Global.currentChatDb).db;
        await (await account.dbHolder.db).update(
          TopicSchema.tableName,
          {
            'expires_at': -1,
            'updated_time': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      NLog.e(e.toString());
      count++;
      if (count > 3) return;
      Future.delayed(Duration(seconds: 3 * count), () {
        // fixme by chenai on 07/07/2020: Are you joke me???
        unsubscribe(account, c: count);
      });
    }
  }

  Future<Map<String, dynamic>> getSubscribers(DChatAccount account, {meta: true, txPool: true, cache: true}) async {
    try {
      Map<String, dynamic> res;
      String topicHash = genChannelId(topic);
      if (!cache) {
        res = await account.client.getSubscribers(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
      } else {
        res = await Permission.getSubscribersFromDbOrNative(account, topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
      }
      NLog.d('$res');
      if (type == TopicType.private) {
        res.removeWhere((key, val) {
          return key.contains('__permission__');
        });
      }
      await setSubscribers(await account.dbHolder.db, res);
      BlocProvider.of<ChannelMembersBloc>(Global.appContext).add(MembersCount(topic, res.length, true));
      return res;
    } catch (e) {
      return getSubscribers(account);
    }
  }

  setSubscribers(Database db, Map<String, dynamic> subscribers) async {
    try {
      SubscribersSchema.deleteSubscribersByTopic(db, topic);
      for (var key in subscribers.keys) {
        var value = subscribers[key];
        await SubscribersSchema(topic: topic, meta: value != null ? value : null, addr: key).insert(db);
      }
    } catch (e) {
      print(e);
      debugPrintStack();
    }
  }

  Future<List<SubscribersSchema>> querySubscribers(Database db) async {
    try {
//      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
        SubscribersSchema.tableName,
        columns: ['*'],
        where: 'topic = ?',
        whereArgs: [topic],
      );
      return res.map((x) => SubscribersSchema.parseEntity(x)).toList();
    } catch (e) {
      print(e);
      debugPrintStack();
    }
  }
}
