import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:common_utils/common_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/options.dart';
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
//  bool isMe;

  File avatar;
  OptionsSchema options;
  DateTime createdTime;
  DateTime updatedTime;
  SourceProfile sourceProfile;
  String profileVersion;
  DateTime profileExpiresAt;

  ContactSchema({
    this.id,
    this.type,
    this.clientAddress,
    this.nknWalletAddress,
    this.firstName,
    this.lastName,
    this.notes,
//    this.isMe = false,
    this.avatar,
    this.options,
    this.createdTime,
    this.updatedTime,
    this.profileVersion,
    this.profileExpiresAt,
  }) {
    name;

//    if (type == ContactType.me || publickKey == Global.currentClient.publicKey) {
//      isMe = true;
//    } else {
//      isMe = false;
//    }
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

  Future<SourceProfile> getSourceProfile() async {
    var res = await getContactByAddress(clientAddress);

    if (res.sourceProfile != null) {
      return res.sourceProfile;
    }
    return null;
  }

  OptionsSchema getOptions() {
    int random = Random().nextInt(DefaultTheme.headerBackgroundColor.length);
    int backgroundColor = DefaultTheme.headerBackgroundColor[random];
    int color = DefaultTheme.headerColor[random];
    if (options == null || options.backgroundColor == null || options.color == null) {
      setOptionColor(backgroundColor, color);
    }
    return options;
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

  Widget avatarWidget({
    Color backgroundColor,
    double size,
    Color fontColor,
    Widget bottomRight,
    GestureTapCallback onTap,
  }) {
    Widget view;

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
    if (avatar == null || avatar.path == null) {
      if (sourceProfile?.avatar != null) {
        view = CircleAvatar(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: bottomRight,
            ),
          ),
          radius: size,
          backgroundImage: FileImage(sourceProfile.avatar),
        );
      } else {
        var wid = <Widget>[
          CircleAvatar(
            radius: size,
            backgroundColor: Color(getOptions().backgroundColor),
            child: Label(
              name.substring(0, 2).toUpperCase(),
              type: fontType,
              color: Color(getOptions().color),
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

        view = Stack(
          children: wid,
        );
      }
    } else {
      view = CircleAvatar(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: bottomRight,
          ),
        ),
        radius: size,
        backgroundImage: FileImage(avatar),
      );
    }

    return view;
  }

  toRequestData(String requestType) {
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.contact,
      'requestType': requestType,
      'version': Global.currentUser.profileVersion,
      'expiresAt': 0,
    };
    return jsonEncode(data);
  }

  toResponseData(String requestType) {
    Map data = {
      'id': uuid.v4(),
      'contentType': ContentType.contact,
      'version': Global.currentUser.profileVersion,
      'expiresAt': 0,
    };
    if (requestType == RequestType.full) {
      try {
        Map<String, dynamic> content = {
          'name': Global.currentUser.firstName,
        };
        if (Global.currentUser?.avatar != null) {
          content['avatar'] = {
            'type': 'base64',
            'data': base64Encode(Global.currentUser.avatar.readAsBytesSync()),
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
    // create table
    await db.execute('''
      CREATE TABLE Contact (
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
      )''');
    // index
    await db.execute('CREATE INDEX index_type ON Contact (type)');
    await db.execute('CREATE INDEX index_address ON Contact (address)');
    await db.execute('CREATE INDEX index_first_name ON Contact (first_name)');
    await db.execute('CREATE INDEX index_last_name ON Contact (last_name)');
    await db.execute('CREATE INDEX index_created_time ON Contact (created_time)');
    await db.execute('CREATE INDEX index_updated_time ON Contact (updated_time)');
  }

  toEntity() {
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
      'avatar': avatar != null ? getLocalContactPath(avatar.path) : null,
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
    LogUtil.v(e);
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
    );
//    contact.type = e['type'];

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

  Future<int> insert() async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      int id = await db.insert(ContactSchema.tableName, toEntity());
      return id;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<int> createContact() async {
    DateTime now = DateTime.now();
    createdTime = now;
    updatedTime = now;
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var countQuery = await db.query(
        ContactSchema.tableName,
        columns: ['COUNT(id) as count'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      var count = countQuery != null ? Sqflite.firstIntValue(countQuery) : 0;
      if (count == 0) {
        if (nknWalletAddress == null || nknWalletAddress.isEmpty) {
          nknWalletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
        }
        return await db.insert(ContactSchema.tableName, toEntity());
      }
      return 0;
    } catch (e) {
      LogUtil.v(e);
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future requestProfile({String type = RequestType.header}) async {
    try {
      await NknClientPlugin.sendText([clientAddress], toRequestData(type));
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future responseProfile({String type = RequestType.header}) async {
    try {
      await NknClientPlugin.sendText([clientAddress], toResponseData(type));
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

//db.query('Test', where: 'name LIKE ?', whereArgs: ['%dummy%']);
  static Future<List<ContactSchema>> getContacts({int limit = 20, int skip = 0}) async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
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
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
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

  static Future<ContactSchema> getContactByAddress(String address) async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
        ContactSchema.tableName,
        columns: ['*'],
        where: 'address = ?',
        whereArgs: [address],
      );
      return ContactSchema.parseEntity(res?.first);
    } catch (e) {
      LogUtil.v(e.toString());
      debugPrintStack();
    }
  }

  Future setProfile(Map<String, dynamic> sourceData) async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
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
              String path = getContactCachePath();
              var extension = 'jpg';
              var bytes = base64Decode(avatarData);
              String name = hexEncode(md5.convert(bytes).bytes);
              File avatar = File(join(path, name + '.$extension'));
              avatar.writeAsBytesSync(bytes);
              data['avatar'] = getLocalContactPath(avatar.path);
            }
          } else {
            data.remove('avatar');
          }

          var count = await db.update(
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
      LogUtil.v(e);
      LogUtil.v('profile fauilt');
      debugPrint(e);
      debugPrintStack();
    }
  }

  Future<bool> setAvatar(File image) async {
    avatar = image;
    Map<String, dynamic> data = {
      'avatar': getLocalContactPath(image.path),
      'type': type,
      'updated_time': DateTime.now().millisecondsSinceEpoch,
    };

    if (type != ContactType.me) {
      type = ContactType.friend;
      data['type'] = type;
    } else {
      profileVersion = uuid.v4();
      data['profile_version'] = profileVersion;
    }
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
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
      var count = await db.update(
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
    if (type != ContactType.me) {
      type = ContactType.friend;
      data['type'] = type;
    } else {
      profileVersion = uuid.v4();
      data['profile_version'] = profileVersion;
    }

    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var count = await db.update(
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
      type = ContactType.friend;
    }

    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
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
      var count = await db.update(
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
    await NknClientPlugin.sendText([clientAddress], jsonEncode(data));
  }

  Future<bool> setOptionColor(int backgroundColor, int color) async {
//    if (type != ContactType.me) {
//      type = ContactType.friend;
//    }

    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      if (options == null) options = OptionsSchema();
      options.backgroundColor = backgroundColor;
      options.color = color;

      var count = await db.update(
        ContactSchema.tableName,
        {
          'options': options.toJson(),
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

  Future<bool> setBurnOptions(int seconds) async {
    if (type != ContactType.me) {
      type = ContactType.friend;
    }

    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      if (options == null) options = OptionsSchema();
      if (seconds != null && seconds > 0) {
        options.deleteAfterSeconds = seconds;
      } else {
        options.deleteAfterSeconds = null;
      }

      var count = await db.update(
        ContactSchema.tableName,
        {
          'options': options.toJson(),
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

  Future<bool> setFriend({bool isFriend = true}) async {
    if (type != ContactType.me) {
      if (isFriend) {
        type = ContactType.friend;
      } else {
        type = ContactType.stranger;
      }
    }
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;

      var count = await db.update(
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
    Database db = SqliteStorage(db: Global.currentChatDb).db;
    var count = await db.delete(ContactSchema.tableName, where: 'id = ?', whereArgs: [id]);

    return count;
  }

  String get publickKey {
    int n = clientAddress.lastIndexOf('.');
    if (n < 0) {
      return clientAddress;
    } else {
      return clientAddress.substring(n + 1);
    }
  }
}
