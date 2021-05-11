import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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
        device_token TEXT
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

  ContactSchema parseEntity(Map e) {
    if (e == null) {
      return null;
    }
    var contact = ContactSchema(
      id: e['id'],
      type: e['type'],
      clientAddress: e['address'],
      firstName: e['first_name'],
      lastName: e['last_name'],
      createdTime: e['created_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['created_time']) : null,
      updatedTime: e['updated_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['updated_time']) : null,
      profileVersion: e['profile_version'],
      profileExpiresAt: e['profile_expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['profile_expires_at']) : DateTime.now(),
      deviceToken: e['device_token'],
      isTop: e['is_top'] == 1 ? true : false,
    );

    if (e['avatar'] != null && e['avatar'].toString().length > 0) {
      contact.avatar = File(join(Global.applicationRootDirectory.path, e['avatar']));
    }

    if (e['data'] != null) {
      try {
        Map<String, dynamic> data = jsonDecode(e['data']);

        if (contact.extraInfo == null) {
          contact.extraInfo = new Map<String, dynamic>();
        }
        contact.extraInfo.addAll(data);
        contact.nknWalletAddress = data['nknWalletAddress'];

        if (contact.firstName == null) {
          var notes = data['notes'].toString();
          if (data['notes'] != null && notes.length > 0) {
            contact.firstName = data['notes'];
          } else if (data['remark_name'] != null) {
            // FIXME: only keeps notes for name
            contact.firstName = data['remark_name'];
          } else if (data['firstName'] != null) {
            // FIXME: only keeps notes for name
            contact.firstName = data['firstName'];
          }
        }

        if (contact.avatar == null) {
          if (data['avatar'] != null) {
            contact.avatar = File(join(Global.applicationRootDirectory.path, data['avatar']));
          } else if (data['remark_avatar'] != null) {
            // FIXME: only keeps avatar
            contact.avatar = File(join(Global.applicationRootDirectory.path, data['remark_avatar']));
          }
        }
      } on FormatException catch (e) {
        logger.e(e);
      }
    }
    contact.options = OptionsSchema();
    if (e['options'] != null) {
      try {
        Map<String, dynamic> options = jsonDecode(e['options']);
        contact.options = OptionsSchema(
          deleteAfterSeconds: options['deleteAfterSeconds'],
          backgroundColor: Color(options['backgroundColor']),
          color: Color(options['color']),
          notificationEnabled: options['notificationEnabled'],
          updateBurnAfterTime: options['updateBurnAfterTime'],
        );
      } on FormatException catch (e) {
        logger.e(e);
      }
    }
    return contact;
  }

  Future<int> queryCountByClientAddress(String clientAddress) async {
    var query = await db.query(
      tableName,
      columns: ['COUNT(id)'],
      where: 'address = ?',
      whereArgs: [clientAddress],
    );
    return Sqflite.firstIntValue(query);
  }

  Future<bool> insertContact(ContactSchema schema) async {
    Map entity = schema.toEntity();
    int n = await db.insert(tableName, entity);
    if (n > 0) {
      return true;
    }
    return false;
  }

  Future<ContactSchema> queryContactByClientAddress(String clientAddress) async {
    var res = await db.query(
      tableName,
      columns: ['*'],
      where: 'address = ?',
      whereArgs: [clientAddress],
    );

    if (res.length > 0) {
      return parseEntity(res.first);
    }
    return null;
  }
}
