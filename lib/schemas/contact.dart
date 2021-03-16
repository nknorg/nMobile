import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/data/contact_data_center.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SourceProfile {
  String firstName;
  String lastName;
  File avatar;

  SourceProfile({this.firstName, this.lastName, this.avatar});

  String get name {
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  String toJson() {
    Map<String, dynamic> map = {};
    if (firstName != null) map['firstName'] = firstName;
    if (lastName != null) map['lastName'] = lastName;
    if (avatar != null) map['avatar'] = base64Encode(avatar.readAsBytesSync());
    return jsonEncode(map);
  }
}

class ContactSchema {
  int id;
  String type;
  String clientAddress;
  String nknWalletAddress;
  String firstName;
  String lastName;
  String notes;
  Map extraInfo;

  File avatar;
  OptionsSchema options;
  DateTime createdTime;
  DateTime updatedTime;
  SourceProfile sourceProfile;
  String profileVersion;
  DateTime profileExpiresAt;

  // deviceToken
  String deviceToken;
  bool notificationOpen;

  ContactSchema({
    this.id,
    this.type,
    this.clientAddress,
    this.nknWalletAddress,
    this.firstName,
    this.lastName,
    this.notes,
    this.avatar,
    this.options,
    this.createdTime,
    this.updatedTime,
    this.profileVersion,
    this.profileExpiresAt,
    this.deviceToken,
    this.notificationOpen,
  });

  bool get isMe {
    if (type == ContactType.me) {
      return true;
    } else {
      return false;
    }
  }

  String get getShowName {
    String showName = '';
    if (firstName != null && firstName.length > 0) {
      showName = firstName;
      if (showName.length > 0) {
        return showName;
      }
    }
    if (sourceProfile != null) {
      if (sourceProfile.firstName != null &&
          sourceProfile.firstName.length > 0) {
        showName = sourceProfile.firstName;
        return showName;
      }
    }
    var index = clientAddress.lastIndexOf('.');
    if (index < 0) {
      showName = clientAddress.substring(0, 6);
    } else {
      showName = clientAddress.substring(0, index + 7);
    }
    return showName;
  }

  String get getShowAvatarPath {
    String avatarPath = '';
    if (avatar?.path != null) {
      avatarPath = avatar.path;
    }
    if (sourceProfile != null) {
      if (sourceProfile.avatar != null &&
          sourceProfile.avatar.path.length > 0) {
        avatarPath = sourceProfile.avatar.path;
      }
    }
    return avatarPath;
  }

  Future<SourceProfile> getSourceProfile(Future<Database> db) async {
    var res = await fetchContactByAddress(clientAddress);

    if (res.sourceProfile != null) {
      return res.sourceProfile;
    }
    return null;
  }

  static String get tableName => 'Contact';

  static create(Database db, int version) async {
    final createSqlV2 = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        address TEXT,
        first_name TEXT,
        last_name TEXT,
        data TEXT,
        options TEXT,
        avatar TEXT,
        created_time INTEGER,
        updated_time INTEGER,
        profile_version TEXT,
        profile_expires_at INTEGER
      )''';
    final createSqlV3 = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        address TEXT,
        first_name TEXT,
        last_name TEXT,
        data TEXT,
        options TEXT,
        avatar TEXT,
        created_time INTEGER,
        updated_time INTEGER,
        profile_version TEXT,
        profile_expires_at INTEGER,
        is_top BOOLEAN DEFAULT 0
      )''';
    final createSqlV4 = '''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        address TEXT,
        first_name TEXT,
        last_name TEXT,
        data TEXT,
        options TEXT,
        avatar TEXT,
        created_time INTEGER,
        updated_time INTEGER,
        profile_version TEXT,
        profile_expires_at INTEGER,
        is_top BOOLEAN DEFAULT 0,
        device_token TEXT,
        notification_open BOOLEAN DEFAULT 0
      )''';
    // create table
    if (version == 2) {
      await db.execute(createSqlV2);
    } else if (version == 3) {
      await db.execute(createSqlV4);
    } else if (version == 5) {
      await db.execute(createSqlV3);
    } else if (version == 6) {
      await db.execute(createSqlV4);
    } else {
      throw UnsupportedError('unsupported create operation version $version.');
    }
    // index
    await db.execute('CREATE INDEX index_type ON $tableName (type)');
    await db.execute('CREATE INDEX index_address ON $tableName (address)');
    await db
        .execute('CREATE INDEX index_first_name ON $tableName (first_name)');
    await db.execute('CREATE INDEX index_last_name ON $tableName (last_name)');
    await db.execute(
        'CREATE INDEX index_created_time ON $tableName (created_time)');
    await db.execute(
        'CREATE INDEX index_updated_time ON $tableName (updated_time)');
  }

  static Future<int> setTop(String chatIdOther, bool top) async {
    Database cdb = await NKNDataManager().currentDatabase();

    return await cdb.update(tableName, {'is_top': top ? 1 : 0},
        where: 'address = ?', whereArgs: [chatIdOther]);
  }

  static Future<bool> getIsTop(String chatIdOther) async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(tableName,
        columns: ['is_top'], where: 'address = ?', whereArgs: [chatIdOther]);
    return res.length > 0 && res[0]['is_top'] as int == 1;
  }

  toEntity(String accountPubkey) {
    if (extraInfo == null) {
      extraInfo = new Map<String, dynamic>();
    }
    if (nknWalletAddress != null)
      extraInfo['nknWalletAddress'] = nknWalletAddress;
    if (notes != null) extraInfo['notes'] = notes;
    if (extraInfo.keys.length == 0) extraInfo = null;
    Map<String, dynamic> map = {
      'type': type,
      'address': clientAddress,
      'first_name': firstName,
      'last_name': lastName,
      'data': extraInfo != null ? jsonEncode(extraInfo) : '{}',
      'options': options?.toJson(),
      'avatar': avatar != null
          ? getLocalContactPath(accountPubkey, avatar.path)
          : null,
      'created_time': createdTime?.millisecondsSinceEpoch,
      'updated_time': updatedTime?.millisecondsSinceEpoch,
      'profile_version': profileVersion,
      'profile_expires_at': profileExpiresAt?.millisecondsSinceEpoch,
    };
    return map;
  }

  static ContactSchema parseEntity(Map e) {
    if (e == null) {
      return null;
    }
    var contact = ContactSchema(
      id: e['id'],
      type: e['type'],
      clientAddress: e['address'],
      firstName: e['first_name'],
      lastName: e['last_name'],
      avatar: e['avatar'] != null
          ? File(join(Global.applicationRootDirectory.path, e['avatar']))
          : null,
      createdTime: DateTime.fromMillisecondsSinceEpoch(e['created_time']),
      updatedTime: DateTime.fromMillisecondsSinceEpoch(e['updated_time']),
      profileVersion: e['profile_version'],
      profileExpiresAt: e['profile_expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(e['profile_expires_at'])
          : DateTime.now(),
      deviceToken: e['device_token'],
    );
    if (e['notification_open'] != null && e['notification_open'] == 1) {
      contact.notificationOpen = true;
    }

    NLog.w('contact.firstName is_____' + e['avatar'].toString());

    if (e['data'] != null) {
      try {
        Map<String, dynamic> data = jsonDecode(e['data']);

        if (contact.extraInfo == null) {
          contact.extraInfo = new Map<String, dynamic>();
        }
        contact.extraInfo.addAll(data);

        NLog.w('contact.extraInfo is_____' + contact.extraInfo.toString());

        contact.nknWalletAddress = data['nknWalletAddress'];
        var notes = data['notes'].toString();
        if (data['notes'] != null && notes.length > 0) {
          contact.firstName = data['notes'];
        } else if (data['remark_name'] != null) {
          contact.firstName = data['remark_name'];
        } else if (data['firstName'] != null) {
          contact.firstName = data['firstName'];
        }
        if (data['remark_avatar'] != null) {
          contact.avatar = File(join(
              Global.applicationRootDirectory.path, data['remark_avatar']));
        } else if (data['avatar'] != null) {
          contact.avatar =
              File(join(Global.applicationRootDirectory.path, data['avatar']));
        }
        // contact.sourceProfile = SourceProfile(
        //   firstName: data['firstName'],
        //   lastName: data['lastName'],
        //   avatar: data['avatar'] != null ? File(join(Global.applicationRootDirectory.path, data['avatar'])) : null,
        // );
      } on FormatException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
      }
    }
    if (e['options'] != null) {
      try {
        Map<String, dynamic> map = jsonDecode(e['options']);
        contact.options = OptionsSchema(
            deleteAfterSeconds: map['deleteAfterSeconds'],
            backgroundColor: map['backgroundColor'],
            color: map['color']);
      } on FormatException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
        contact.options = OptionsSchema();
      }
    }
    return contact;
  }

  Future<int> insertContact() async {
    Database cdb = await NKNDataManager().currentDatabase();
    DateTime now = DateTime.now();
    createdTime = now;
    updatedTime = now;
    try {
      var countQuery = await cdb.query(
        ContactSchema.tableName,
        columns: ['*'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      if (countQuery != null && countQuery.length > 0) {
        id = ContactSchema.parseEntity(countQuery?.first).id;
        return 0;
      } else {
        if (nknWalletAddress == null || nknWalletAddress.isEmpty) {
          nknWalletAddress = await NknWalletPlugin.pubKeyToWalletAddr(
              getPublicKeyByClientAddr(clientAddress));
        }
        return await cdb.insert(
            ContactSchema.tableName, toEntity(clientAddress));
      }
    } catch (e) {
      NLog.w('Wrong!!! InsertContact E:'+e.toString());
      return 0;
    }
  }

  static Future<List<ContactSchema>> getContacts(
      {int limit = 20, int skip = 0}) async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      ContactSchema.tableName,
      columns: ['*'],
      orderBy: 'updated_time desc',
      where: 'type = ?',
      whereArgs: [ContactType.friend],
      limit: limit,
      offset: skip,
    );
    if (res == null || res.length == 0) {
      return [];
    }
    return res.map((x) => parseEntity(x)).toList();
  }

  static Future<List<ContactSchema>> getStrangerContacts(
      {int limit = 20, int skip = 0}) async {
    try {
      Database cdb = await NKNDataManager().currentDatabase();
      var res = await cdb.query(
        ContactSchema.tableName,
        columns: ['*'],
        orderBy: 'updated_time desc',
        where: 'type = ?',
        whereArgs: [ContactType.stranger],
        limit: limit,
        offset: skip,
      );
      if (res == null || res.length == 0) {
        return [];
      }
      return res.map((x) => parseEntity(x)).toList();
    } catch (e) {
      debugPrintStack();
      return [];
    }
  }

  static Future<ContactSchema> fetchContactByAddress(
      String clientAddress) async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      ContactSchema.tableName,
      columns: ['*'],
      where: 'address = ?',
      whereArgs: [clientAddress],
    );
    if (res.length > 0) {
      return ContactSchema.parseEntity(res.first);
    }
    return null;
  }

  static Future<ContactSchema> fetchCurrentUser() async {
    Database cdb = await NKNDataManager().currentDatabase();
    if (cdb == null) {
      return null;
    }
    var res = await cdb.query(
      ContactSchema.tableName,
      columns: ['*'],
      where: 'address = ?',
      whereArgs: [NKNClientCaller.currentChatId],
    );
    if (res.length > 0) {
      return ContactSchema.parseEntity(res.first);
    }
    return null;
  }

  Future setOrUpdateExtraProfile(Map<String, dynamic> updateInfo) async {
    try {
      Database cdb = await NKNDataManager().currentDatabase();
      String pubKey = NKNClientCaller.currentChatId;
      var res = await cdb.query(
        ContactSchema.tableName,
        columns: ['*'],
        where: 'id = ?',
        whereArgs: [id],
      );
      var record = res?.first;
      if (record != null) {
        var content = updateInfo['content'];
        if (content != null) {
          Map<String, dynamic> data = jsonDecode(record['data']);
          if (content['name'] != null) {
            data['firstName'] = content['name'];
          }
          if (content['avatar'] != null) {
            var type = content['avatar']['type'];
            if (type == 'base64') {
              var avatarData;
              if (content['avatar']['data'].toString().split(",").length == 1) {
                avatarData = content['avatar']['data'];
              } else {
                avatarData = content['avatar']['data'].toString().split(",")[1];
              }
              String path = getContactCachePath(pubKey);
              var extension = 'jpg';
              var bytes = base64Decode(avatarData);
              String name = hexEncode(md5.convert(bytes).bytes);
              File avatar = File(join(path, name + '.$extension'));
              avatar.writeAsBytesSync(bytes);
              data['avatar'] = getLocalContactPath(pubKey, avatar.path);
            }
          } else {
            /// do not remove
            // data.remove('avatar');
            NLog.w('Receive batch request full-response message');
          }
          if (extraInfo == null) {
            extraInfo = new Map<String, dynamic>();
          }
          extraInfo.addAll(data);
          var count = await cdb.update(
            ContactSchema.tableName,
            {
              'data': jsonEncode(extraInfo),
              'profile_version': updateInfo['version'],
              'profile_expires_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          NLog.w('Update profile Success____' + count.toString());
          NLog.w('Update profile toVersion_____' +
              updateInfo['version'].toString());
        }
      }
    } catch (e) {
      NLog.w('SetProfile___e' + e.toString());
    }
  }

  Future<bool> setAvatar(File image) async {
    Map<String, dynamic> profileInfo = {
      'avatar': image.path,
    };
    return await ContactDataCenter.saveProfile(this, profileInfo);
  }

  Future<bool> setName(String firstName) async {
    Map<String, dynamic> profileInfo = {
      'first_name': firstName,
    };
    return await ContactDataCenter.saveProfile(this, profileInfo);
  }

  Future<bool> updateExpiresAtTime() async {
    Map<String, dynamic> profileInfo = {
      'profile_expires_at': profileExpiresAt?.millisecondsSinceEpoch,
    };
    return await ContactDataCenter.saveProfile(this, profileInfo);
  }

  Future<bool> setProfileVersion(String profileVersion) async {
    Map<String, dynamic> profileInfo = {
      'profile_version': profileVersion,
    };
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      ContactSchema.tableName,
      profileInfo,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count > 0) {
      NLog.w('UpdateInfo Success__' + profileInfo.toString());
      return true;
    }
    NLog.w('UpdateInfo Failed___' + profileInfo.toString());
    return false;
  }

  Future<bool> setNotificationOpen(bool notificationOpen) async {
    int notificationSaveValue = 0;
    if (notificationOpen == true) {
      notificationSaveValue = 1;
    }
    this.notificationOpen = notificationOpen;
    Map<String, dynamic> profileInfo = {
      'notification_open': notificationSaveValue,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      ContactSchema.tableName,
      profileInfo,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count > 0) {
      NLog.w('setNotificationOpen Success___' + profileInfo.toString());
      return true;
    }
    NLog.w('setNotificationOpen Failed___' + profileInfo.toString());
    return false;
  }

  Future<bool> setDeviceToken(String deviceToken) async {
    Map<String, dynamic> profileInfo = {
      'device_token': deviceToken,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      ContactSchema.tableName,
      profileInfo,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count > 0) {
      NLog.w('setDeviceToken Success___' + count.toString());
      return true;
    }
    NLog.w('setDeviceToken Failed___' + profileInfo.toString());
    return false;
  }

  Future<bool> setNotes(String notes) async {
    if (type != ContactType.me) {
      if (type == ContactType.friend) {
        type = ContactType.friend;
      } else {
        type = ContactType.stranger;
      }
    }
    try {
      Database cdb = await NKNDataManager().currentDatabase();
      var res = await cdb.query(
        ContactSchema.tableName,
        columns: ['*'],
        where: 'id = ?',
        whereArgs: [id],
      );
      var record = res?.first;
      Map<String, dynamic> data;
      if (record['data'] != null) {
        data = jsonDecode(record['data']);
      } else {
        data = {};
      }
      data['notes'] = notes;
      var count = await cdb.update(
        ContactSchema.tableName,
        {
          'data': jsonEncode(data),
          'type': type,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return count > 0;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
      return false;
    }
  }

  Future sendActionContactOptions() async {
    String msgId = uuid.v4();
    Map data = {
      'id': msgId,
      'contentType': ContentType.eventContactOptions,
      'content': {'deleteAfterSeconds': options?.deleteAfterSeconds},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      NKNClientCaller.sendText([clientAddress], jsonEncode(data), msgId);
    } catch (e) {
      NLog.w('Wrong!!! sendActionContactOptions' + e.toString());
    }
  }

  Future<bool> setOptionColor() async {
    int random = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
    int backgroundColor = DefaultTheme.headerBackgroundColor[random];
    int color = DefaultTheme.headerColor[random];
    Database cdb = await NKNDataManager().currentDatabase();

    if (options == null) {
      options = OptionsSchema(backgroundColor: backgroundColor, color: color);
    }
    options.backgroundColor = backgroundColor;
    options.color = color;
    var count = await cdb.update(
      ContactSchema.tableName,
      {
        'options': options.toJson(),
        'updated_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'address = ?',
      whereArgs: [clientAddress],
    );
    return count > 0;
  }

  Future<bool> setBurnOptions(int seconds) async {
    Database cdb = await NKNDataManager().currentDatabase();
    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch;
    try {
      if (options == null) options = OptionsSchema();
      if (seconds != null && seconds > 0) {
        options.deleteAfterSeconds = seconds;
      } else {
        options.deleteAfterSeconds = null;
      }
      options.updateBurnAfterTime = currentTimeStamp;

      var count = await cdb.update(
        ContactSchema.tableName,
        {
          'options': options.toJson(),
          'updated_time': currentTimeStamp,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      NLog.w('setBurnOptions E:' + e.toString());
    }
    return false;
  }

  Future<bool> setFriend(bool isFriend) async {
    if (clientAddress == NKNClientCaller.currentChatId) {
      type = ContactType.me;
      NLog.w('QrCode to self__');
      return true;
    }

    Database cdb = await NKNDataManager().currentDatabase();
    if (type == null || type != ContactType.me) {
      if (isFriend) {
        type = ContactType.friend;
      } else {
        type = ContactType.stranger;
      }
      try {
        var count = await cdb.update(
          ContactSchema.tableName,
          {
            'type': type,
            'updated_time': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        return count > 0;
      } catch (e) {
        NLog.w('setFriend E:' + e.toString());
        return false;
      }
    }
    return false;
  }

  Future<int> deleteContact() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb
        .delete(ContactSchema.tableName, where: 'id = ?', whereArgs: [id]);

    return count;
  }

  String get publicKey {
    int n = clientAddress.lastIndexOf('.');
    if (n < 0) {
      return clientAddress;
    } else {
      return clientAddress.substring(n + 1);
    }
  }
}
