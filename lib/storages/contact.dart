import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

class ContactStorage {
  static String get tableName => 'Contact';

  Database get db => DB.currentDatabase;

  static create(Database db, int version) async {
    final createSql = '''
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
    db.execute(createSql);

    // index
    await db.execute('CREATE INDEX index_contact_type ON $tableName (type)');
    await db.execute('CREATE INDEX index_contact_address ON $tableName (address)');
    await db.execute('CREATE INDEX index_contact_first_name ON $tableName (first_name)');
    await db.execute('CREATE INDEX index_contact_last_name ON $tableName (last_name)');
    await db.execute('CREATE INDEX index_contact_created_time ON $tableName (created_time)');
    await db.execute('CREATE INDEX index_contact_updated_time ON $tableName (updated_time)');
  }

  Future<ContactSchema> insertContact(ContactSchema schema) async {
    if (schema == null) return null;
    try {
      ContactSchema exist = await queryContactByClientAddress(schema?.clientAddress);
      if (exist != null) {
        logger.d("insertContact - exist:$exist - add:$schema");
        return exist;
      }
      Map entity = await schema.toMap();
      int id = await db.insert(tableName, entity);
      if (id != 0) {
        ContactSchema schema = await ContactSchema.fromMap(entity);
        logger.d("insertContact - success - schema:$schema");
        return schema;
      }
      logger.w("insertContact - fail - scheme:$schema");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<bool> deleteContact(int contactId) async {
    if (contactId == null || contactId == 0) return false;
    try {
      var count = await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("deleteContact - success - contactId:$contactId");
        return true;
      }
      logger.w("deleteContact - fail - contactId:$contactId");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// Query

  Future<ContactSchema> queryContactByClientAddress(String clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    try {
      var res = await db.query(
        tableName,
        columns: ['*'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      if (res.length > 0) {
        ContactSchema schema = await ContactSchema.fromMap(res.first);
        logger.d("queryContactByClientAddress - success - address:$clientAddress - schema:$schema");
        return schema;
      }
      logger.d("queryContactByClientAddress - empty - address:$clientAddress");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<int> queryCountByClientAddress(String clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return 0;
    try {
      var res = await db.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      int count = Sqflite.firstIntValue(res);
      logger.d("queryCountByClientAddress - address:$clientAddress - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<List<ContactSchema>> queryContacts({String contactType, int limit = 20, int offset = 0}) async {
    try {
      var res = await db.query(
        tableName,
        columns: ['*'],
        orderBy: 'updated_time desc', // TODO: GG top
        where: contactType != null ? 'type = ?' : '',
        whereArgs: contactType != null ? [contactType] : [],
        limit: limit,
        offset: offset,
      );
      if (res == null || res.isEmpty) {
        logger.d("queryContacts - empty - contactType:$contactType");
        return [];
      }
      List<Future<ContactSchema>> futures = <Future<ContactSchema>>[];
      res.forEach((map) {
        logger.d("queryContacts - item:$map");
        futures.add(ContactSchema.fromMap(map));
      });
      return await Future.wait(futures);
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  /// Type

  Future<bool> setType(int contactId, String contactType) async {
    if (contactType == null || contactType == ContactType.me) return false;
    try {
      var count = await db.update(
        tableName,
        {
          'type': contactType,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setContactType - success - contactId:$contactId - type:$contactType");
        return true;
      }
      logger.w("setContactType - fail - contactId:$contactId - type:$contactType");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// Profile

  Future<bool> setProfile(int contactId, Map newProfileInfo, {Map oldProfileInfo}) async {
    if (contactId == null || contactId == 0 || newProfileInfo == null) return false;

    Map saveDataInfo = oldProfileInfo ?? Map<String, dynamic>();

    if (newProfileInfo['avatar'] != null) {
      saveDataInfo['avatar'] = newProfileInfo['avatar'];
    }
    if (newProfileInfo['first_name'] != null) {
      saveDataInfo['first_name'] = newProfileInfo['first_name'];
    }
    if (newProfileInfo['last_name'] != null) {
      saveDataInfo['last_name'] = newProfileInfo['last_name'];
    }
    if (newProfileInfo['profile_expires_at'] != null) {
      saveDataInfo['profile_expires_at'] = newProfileInfo['profile_expires_at'];
    }
    saveDataInfo['profile_version'] = Uuid().v4();
    saveDataInfo['updated_time'] = DateTime.now().millisecondsSinceEpoch;

    try {
      var count = await db.update(
        tableName,
        saveDataInfo,
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setProfile - success - contactId:$contactId - new:$newProfileInfo - old:$oldProfileInfo");
        return true;
      }
      logger.w("setProfile - fail - contactId:$contactId - new:$newProfileInfo - old:$oldProfileInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setAvatar(ContactSchema schema, String path) async {
    if (schema == null || path == null || path.isEmpty) return false;
    return await setProfile(schema.id, {'avatar': path}, oldProfileInfo: {'avatar': schema.avatar});
  }

  Future<bool> setName(ContactSchema schema, String name) async {
    if (schema == null || name == null || name.isEmpty) return false;
    return await setProfile(schema.id, {'first_name': name}, oldProfileInfo: {'first_name': schema.firstName});
  }

  Future<bool> setProfileVersion(int contactId, String profileVersion) async {
    if (contactId == null || contactId == 0 || profileVersion == null) return false;
    try {
      var count = await db.update(
        tableName,
        {
          'profile_version': profileVersion,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setProfileVersion - success - contactId:$contactId - version:$profileVersion");
        return true;
      }
      logger.w("setProfileVersion - fail - contactId:$contactId - version:$profileVersion");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setProfileExpiresAt(int contactId, int expiresAt) async {
    if (contactId == null || contactId == 0 || expiresAt == null) return false;
    try {
      var count = await db.update(
        tableName,
        {
          'profile_expires_at': expiresAt,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setProfileExpiresAt - success - contactId:$contactId - expiresAt:$expiresAt");
        return true;
      }
      logger.w("setProfileExpiresAt - fail - contactId:$contactId - expiresAt:$expiresAt");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// RemarkProfile(Data)

  Future<bool> setRemarkProfile(int contactId, Map newExtraInfo, {Map oldExtraInfo}) async {
    if (contactId == null || contactId == 0 || newExtraInfo == null) return false;

    Map dataInfo = oldExtraInfo ?? Map<String, dynamic>();
    if (newExtraInfo['first_name'] != null) {
      dataInfo['remark_name'] = newExtraInfo['first_name'];
    }
    if (newExtraInfo['avatar'] != null) {
      dataInfo['remark_avatar'] = newExtraInfo['remark_avatar'];
    }

    Map saveDataInfo = Map<String, dynamic>();
    saveDataInfo['data'] = jsonEncode(dataInfo);

    try {
      var count = await db.update(
        tableName,
        saveDataInfo,
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setRemarkProfile - success - contactId:$contactId - new:$newExtraInfo - old:$oldExtraInfo");
        return true;
      }
      logger.w("setRemarkProfile - fail - contactId:$contactId - new:$newExtraInfo - old:$oldExtraInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // TODO:GG setOrUpdateExtraProfile need??

  /// notes(Data)

  Future<bool> setNotes(int contactId, String notes, {Map oldExtraInfo}) async {
    try {
      Map<String, dynamic> data = oldExtraInfo ?? Map();
      data['notes'] = notes;
      var count = await db.update(
        tableName,
        {
          'data': jsonEncode(data),
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setNotes - success - contactId:$contactId - new:$notes - old:$oldExtraInfo");
        return true;
      }
      logger.w("setNotes - fail - contactId:$contactId - new:$notes - old:$oldExtraInfo");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// Options

  Future<bool> setOptionsColors(int contactId, {OptionsSchema old}) async {
    if (contactId == null || contactId == 0) return false;

    int random = Random().nextInt(application.theme.randomBackgroundColorList.length);
    Color backgroundColor = application.theme.randomBackgroundColorList[random];
    Color color = application.theme.randomColorList[random];

    OptionsSchema options = old ?? OptionsSchema(backgroundColor: backgroundColor, color: color);
    options.backgroundColor = backgroundColor;
    options.color = color;

    try {
      var count = await db.update(
        tableName,
        {
          'options': jsonEncode(options),
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setOptionsColors - success - contactId:$contactId - options:$options");
        return true;
      }
      logger.w("setOptionsColors - fail - contactId:$contactId - options:$options");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> setOptionsBurn(int contactId, int seconds, {OptionsSchema old}) async {
    if (contactId == null || contactId == 0) return false;
    OptionsSchema options = old ?? OptionsSchema();

    if (seconds != null && seconds > 0) {
      options.deleteAfterSeconds = seconds;
    } else {
      options.deleteAfterSeconds = null;
    }

    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch;
    options.updateBurnAfterTime = currentTimeStamp;

    try {
      var count = await db.update(
        tableName,
        {
          'options': jsonEncode(options),
          'updated_time': currentTimeStamp,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setOptionsBurn - success - contactId:$contactId - options:$options");
        return true;
      }
      logger.w("setOptionsBurn - fail - contactId:$contactId - options:$options");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// Top

  Future<bool> setTop(String clientAddress, bool top) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    try {
      var count = await db.update(
        tableName,
        {'is_top': top ? 1 : 0},
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      if (count > 0) {
        logger.d("setTop - success - clientAddress:$clientAddress - top:$top");
        return true;
      }
      logger.w("setTop - fail - clientAddress:$clientAddress - top:$top");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> isTop(String clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    try {
      var res = await db.query(
        tableName,
        columns: ['is_top'],
        where: 'address = ?',
        whereArgs: [clientAddress],
      );
      return res.length > 0 && ((res[0]['is_top'] as int) == 1);
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// DeviceToken

  Future<bool> setDeviceToken(int contactId, String deviceToken) async {
    if (contactId == null || contactId == 0 || deviceToken == null || deviceToken.isEmpty) return false;
    try {
      var count = await db.update(
        tableName,
        {
          'device_token': deviceToken,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setDeviceToken - success - contactId:$contactId - deviceToken:$deviceToken");
        return true;
      }
      logger.w("setDeviceToken - fail - contactId:$contactId - deviceToken:$deviceToken");
      return false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  /// NotificationOpen

  Future<bool> setNotificationOpen(int contactId, bool open) async {
    if (contactId == null || contactId == 0 || open == null) return false;
    try {
      var count = await db.update(
        tableName,
        {
          'notification_open': open ? 1 : 0,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      if (count > 0) {
        logger.d("setNotificationOpen - success - contactId:$contactId - open:$open");
        return true;
      }
      logger.w("setNotificationOpen - fail - contactId:$contactId - open:$open");
      return false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
