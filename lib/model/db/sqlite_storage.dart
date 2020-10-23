import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/contact_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/nkn_data_manager.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SqliteStorage {
  static const String _CHAT_DATABASE_NAME = 'nkn';

  final String name;
  final String _password;

  static int currentVersion = 5;
  Database _db;

  SqliteStorage(String publicKey, String password)
      : name = publicKey2DbName(publicKey),
        _password = password;

  Future<Database> get db async {
    _db ??= await _open(name, _password);
    return _db;
  }

  Future<void> close() {
    final db = _db;
    _db = null;
    return db?.close();
  }

  Future delete() {
    return _delete(name);
  }

  static String publicKey2DbName(String publicKey) {
    return '${_CHAT_DATABASE_NAME}_$publicKey';
  }

  static Future<Database> _open(String name, String password) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '$name.db');
    var db = await openDatabase(
      path,
      password: password,
      version: 5,
      onCreate: (Database db, int version) async {
        await MessageSchema.create(db, version);
        await ContactSchema.create(db, version);
        var now = DateTime.now();
        var publicKey = name.replaceFirst(_CHAT_DATABASE_NAME + '_', '');
        var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(publicKey);
        await db.insert(
            ContactSchema.tableName,
            ContactSchema(
              type: ContactType.me,
              clientAddress: publicKey,
              nknWalletAddress: walletAddress,
              createdTime: now,
              updatedTime: now,
              profileVersion: uuid.v4(),
            ).toEntity(publicKey));
        if (version <= 3) {
//          await TopicSchema.create(db, version);
//          await SubscribersSchema.create(db, version);
        } else {
          await TopicRepo.create(db, version);
          await SubscriberRepo.create(db, version);
          await BlackListRepo.create(db, version);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        print('old v is'+oldVersion.toString()+'new V is'+newVersion.toString());
        // await ContactSchema.upgrade(db, oldVersion, newVersion);
        if (newVersion <= 3) {
//          await TopicSchema.upgrade(db, oldVersion, newVersion);
        } else {
          await TopicRepo.upgradeFromV5(db, oldVersion, newVersion);
          await SubscriberRepo.upgradeFromV5(db, oldVersion, newVersion);
          await BlackListRepo.upgradeFromV5(db, oldVersion, newVersion);
        }
        await NKNDataManager.upgradeContactSchema2V3(db, newVersion);
      },
    );
    return db;
  }

  static Future _delete(String name) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '$name.db');
    try {
      await deleteDatabase(path);
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }
}
