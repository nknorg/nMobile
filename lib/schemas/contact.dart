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
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ContactType {
  static const String stranger = 'stranger';
  static const String friend = 'friend';
  static const String me = 'me';
}

class RequestType {
  static const String header = 'header';
  static const String full = 'full';
}

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
  }) {
    name;
  }

  bool get isMe {
    if (type == ContactType.me) {
      return true;
    } else {
      return false;
    }
  }

  String get name {
    var firstName, lastName;
    if (this.firstName == null || this.firstName.isEmpty) {
      if (sourceProfile?.firstName == null || sourceProfile.firstName.isEmpty) {
        var index = clientAddress.lastIndexOf('.');
        if (index < 0) {
          firstName = clientAddress.substring(0, 6);
        } else {
          firstName = clientAddress.substring(0, index + 7);
        }
      } else {
        firstName = sourceProfile.firstName;
        lastName = sourceProfile.lastName;
      }
      return '${firstName ?? ''} '.trim();
    } else {
      return '${this.firstName ?? ''}'.trim();
    }
  }

  Future<SourceProfile> getSourceProfile(Future<Database> db) async {
    var res = await fetchContactByAddress(clientAddress);

    if (res.sourceProfile != null) {
      return res.sourceProfile;
    }
    return null;
  }

  String get avatarFilePath {
    if (avatar?.path != null) {
      return avatar.path;
    } else {
      if (sourceProfile?.avatar != null) {
        return sourceProfile.avatar.path;
      } else {
        return null;
      }
    }
  }

  Future<String> toRequestData(String requestType) async {
    // Saved other's contact data.
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.contact,
      'requestType': requestType,
      'version': profileVersion,
      'expiresAt': 0,
    };
    return jsonEncode(data);
  }

  Future<String> toResponseData(String requestType) async {
    String myChatId = NKNClientCaller.pubKey;
    final me = await fetchContactByAddress(myChatId);
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.contact,
      'version': me.profileVersion,
      'expiresAt': 0,
    };
    if (requestType == RequestType.full) {
      try {
        Map<String, dynamic> content = {
          'name': me.firstName,
        };
        if (me?.avatar != null) {
          content['avatar'] = {
            'type': 'base64',
            'data': base64Encode(me.avatar.readAsBytesSync()),
          };
        }

        data['content'] = content;
      } catch (e) {
        print(e);
      }
    }

    return jsonEncode(data);
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
    }
    else if (version == 6){
      await db.execute(createSqlV4);
    }
    else {
      throw UnsupportedError('unsupported create operation version $version.');
    }
    // index
    await db.execute('CREATE INDEX index_type ON $tableName (type)');
    await db.execute('CREATE INDEX index_address ON $tableName (address)');
    await db.execute('CREATE INDEX index_first_name ON $tableName (first_name)');
    await db.execute('CREATE INDEX index_last_name ON $tableName (last_name)');
    await db.execute('CREATE INDEX index_created_time ON $tableName (created_time)');
    await db.execute('CREATE INDEX index_updated_time ON $tableName (updated_time)');
  }

  static Future<int> setTop(String chatIdOther, bool top) async {
    Database cdb = await NKNDataManager().currentDatabase();

    return await cdb.update(tableName, {'is_top': top ? 1 : 0}, where: 'address = ?', whereArgs: [chatIdOther]);
  }

  static Future<bool> getIsTop(String chatIdOther) async {
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(tableName, columns: ['is_top'], where: 'address = ?', whereArgs: [chatIdOther]);
    return res.length > 0 && res[0]['is_top'] as int == 1;
  }

  toEntity(String accountPubkey) {
    Map<String, dynamic> data = {};
    if (nknWalletAddress != null) data['nknWalletAddress'] = nknWalletAddress;
    if (notes != null) data['notes'] = notes;
    if (data.keys.length == 0) data = null;
    Map<String, dynamic> map = {
      'type': type,
      'address': clientAddress,
      'first_name': firstName,
      'last_name': lastName,
      'data': data != null ? jsonEncode(data) : '{}',
      'options': options?.toJson(),
      'avatar': avatar != null ? getLocalContactPath(accountPubkey, avatar.path) : null,
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
      avatar: e['avatar'] != null ? File(join(Global.applicationRootDirectory.path, e['avatar'])) : null,
      createdTime: DateTime.fromMillisecondsSinceEpoch(e['created_time']),
      updatedTime: DateTime.fromMillisecondsSinceEpoch(e['updated_time']),
      profileVersion: e['profile_version'],
      profileExpiresAt: e['profile_expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['profile_expires_at']) : DateTime.now(),
      deviceToken: e['device_token'],
    );
    if (e['notification_open'] == '1' || e['notification_open'].toString() == 'true' || e['notification_open'] == 1){
      contact.notificationOpen = true;
    }

    if (e['data'] != null) {
      try {
        Map<String, dynamic> data = jsonDecode(e['data']);
        contact.nknWalletAddress = data['nknWalletAddress'];
        contact.notes = data['notes'];
        contact.sourceProfile = SourceProfile(
          firstName: data['firstName'],
          lastName: data['lastName'],
          avatar: data['avatar'] != null ? File(join(Global.applicationRootDirectory.path, data['avatar'])) : null,
        );
      } on FormatException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
      }
    }
    if (e['options'] != null) {
      try {
        Map<String, dynamic> map = jsonDecode(e['options']);
        contact.options = OptionsSchema(deleteAfterSeconds: map['deleteAfterSeconds'], backgroundColor: map['backgroundColor'], color: map['color']);
      } on FormatException catch (e) {
        debugPrint(e.message);
        debugPrintStack();
        contact.options = OptionsSchema();
      }
    }
    return contact;
  }


  Future <int> insertContact() async{
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
          nknWalletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
        }
        return await cdb.insert(ContactSchema.tableName, toEntity(clientAddress));
      }
    } catch (e) {
      return 0;
    }
  }

  Future requestProfile({String type = RequestType.header}) async {
    try {
      await NKNClientCaller.sendText([clientAddress], await toRequestData(type));
    } catch (e) {
      debugPrint(e?.toString());
    }
  }

  Future responseProfile({String type = RequestType.header}) async {
    try {
      await NKNClientCaller.sendText([clientAddress], await toResponseData(type));
    } catch (e) {
      debugPrint(e?.toString());
    }
  }

  static Future<List<ContactSchema>> getContacts({int limit = 20, int skip = 0}) async {
    try {
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
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static Future<List<ContactSchema>> getStrangerContacts({int limit = 20, int skip = 0}) async {
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
    }
  }

  static Future<ContactSchema> fetchContactByAddress(String clientAddress) async{
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      ContactSchema.tableName,
      columns: ['*'],
      where: 'address = ?',
      whereArgs: [clientAddress],
    );
    if (res.length > 0){
      return ContactSchema.parseEntity(res.first);
    }
    return null;
  }

  static Future<ContactSchema> fetchCurrentUser() async{
    Database cdb = await NKNDataManager().currentDatabase();
    var res = await cdb.query(
      ContactSchema.tableName,
      columns: ['*'],
      where: 'address = ?',
      whereArgs: [NKNClientCaller.currentChatId],
    );
    if (res.length > 0){
      return ContactSchema.parseEntity(res.first);
    }
    return null;
  }

  Future setProfile(Map<String, dynamic> sourceData) async {
    try {
      Database cdb = await NKNDataManager().currentDatabase();
      String pubKey = NKNClientCaller.pubKey;
      var res = await cdb.query(
        ContactSchema.tableName,
        columns: ['*'],
        where: 'id = ?',
        whereArgs: [id],
      );
      var record = res?.first;
      if (record != null) {
        var content = sourceData['content'];
        if (content != null) {
          Map<String, dynamic> data = jsonDecode(record['data']);
          data['firstName'] = content['name'];
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
            data.remove('avatar');
          }

          var count = await cdb.update(
            ContactSchema.tableName,
            {
              'data': jsonEncode(data),
              'profile_version': sourceData['version'],
              'profile_expires_at': DateTime.now().add(Duration(minutes: 3)).millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (e) {
      NLog.d(e);
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<bool> setAvatar(String accountPubkey, File image) async {
    Database cdb = await NKNDataManager().currentDatabase();

    avatar = image;
    Map<String, dynamic> data = {
      'avatar': getLocalContactPath(accountPubkey, image.path),
      'type': type,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };

    if (type != ContactType.me) {
      if (type == ContactType.friend){
        type = ContactType.friend;
      }
      else{
        type = ContactType.stranger;
      }
      data['type'] = type;
    }
    else {
      profileVersion = uuid.v4();
      data['profile_version'] = profileVersion;
    }
    try {
      var res = await cdb.query(
        ContactSchema.tableName,
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
      var count = await cdb.update(
        ContactSchema.tableName,
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

  Future<bool> setName(String firstName) async {
    Map<String, dynamic> data = {
      'first_name': firstName,
      'last_name': "",
      'type': type,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };
    this.firstName = firstName;
    if (type != ContactType.me) {
      if (type == ContactType.friend){
        type = ContactType.friend;
      }
      else{
        type = ContactType.stranger;
      }
      data['type'] = type;
    } else {
      profileVersion = uuid.v4();
      data['profile_version'] = profileVersion;
    }

    try {
      Database cdb = await NKNDataManager().currentDatabase();
      var count = await cdb.update(
        ContactSchema.tableName,
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

  Future<bool> setDeviceToken(String deviceToken) async {
    Map<String, dynamic> data = {
      'device_token': deviceToken,
      'type': type,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };
    this.deviceToken = deviceToken;
    if (type != ContactType.me) {
      if (type == ContactType.friend){
        type = ContactType.friend;
      }
      else{
        type = ContactType.stranger;
      }
      data['type'] = type;
    } else {
      profileVersion = uuid.v4();
      data['profile_version'] = profileVersion;
    }
    return updateContactDataById(data);
  }

  Future<bool> setNotificationOpen(bool notificationOpen) async {
    Map<String, dynamic> data = {
      'notification_open': notificationOpen?1:0,
      'type': type,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };
    if (type != ContactType.me) {
      if (type == ContactType.friend){
        type = ContactType.friend;
      }
      else{
        type = ContactType.stranger;
      }
      data['type'] = type;
    } else {
      profileVersion = uuid.v4();
      data['profile_version'] = profileVersion;
    }
    print("setNotification Open"+notificationOpen.toString());
    return updateContactDataById(data);
  }

  Future <bool> updateContactDataById(Map data) async{
    try {
      Database cdb = await NKNDataManager().currentDatabase();
      var count = await cdb.update(
        ContactSchema.tableName,
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

  Future<bool> setNotes(String notes) async {
    if (type != ContactType.me) {
      if (type == ContactType.friend){
        type = ContactType.friend;
      }
      else{
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
    }
  }

  Future sendActionContactOptions() async {
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.eventContactOptions,
      'content': {'deleteAfterSeconds': options?.deleteAfterSeconds},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await NKNClientCaller.sendText([clientAddress], jsonEncode(data));
  }

  Future<bool> setOptionColor() async {
    int random = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
    int backgroundColor = DefaultTheme.headerBackgroundColor[random];
    int color = DefaultTheme.headerColor[random];
    Database cdb = await NKNDataManager().currentDatabase();
    print('Update setOptionColor is'+clientAddress.toString());
    if (options == null){
      options = OptionsSchema(backgroundColor: backgroundColor,color: color);
    }
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
    if (type != ContactType.me) {
      if (type == ContactType.friend){
        type = ContactType.friend;
      }
      else{
        type = ContactType.stranger;
      }
    }
    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch-5*1000;
    try {
      if (options == null) options = OptionsSchema();
      if (seconds != null && seconds > 0) {
        options.deleteAfterSeconds = seconds;
      } else {
        options.deleteAfterSeconds = null;
      }

      var count = await cdb.update(
        ContactSchema.tableName,
        {
          'options': options.toJson(),
          'type': type,
          'updated_time': currentTimeStamp,
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

  Future<bool> setFriend({bool isFriend = true}) async {
    Database cdb = await NKNDataManager().currentDatabase();
    if (type != ContactType.me) {
      if (isFriend) {
        type = ContactType.friend;
      } else {
        type = ContactType.stranger;
      }
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
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<int> deleteContact() async {
    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.delete(ContactSchema.tableName, where: 'id = ?', whereArgs: [id]);

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

  String get nickName {
    String name;
    if (sourceProfile?.firstName == null || sourceProfile.firstName.isEmpty) {
      var index = clientAddress.lastIndexOf('.');
      if (index < 0) {
        name = clientAddress.substring(0, 6);
      } else {
        name = clientAddress.substring(0, index + 7);
      }
    } else {
      name = sourceProfile.firstName;
    }
    return '${name ?? ''} '.trim();
  }
}
