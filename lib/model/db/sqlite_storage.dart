import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/model/data/contact_data_center.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SqliteStorage {
  static const String _CHAT_DATABASE_NAME = 'nkn';

  final String name;
  final String _password;

  static int currentVersion = 3;
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
      version: currentVersion,
      onCreate: (Database db, int version) async {
        await MessageSchema.create(db, version);
        await ContactSchema.create(db, version);
        var now = DateTime.now();

        NLog.w('Database name is' + name.toString());
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
        await TopicRepo.create(db, version);
        await SubscriberRepo.create(db, version);
        await BlackListRepo.create(db, version);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (newVersion <= currentVersion) {
          await NKNDataManager.upgradeTopicTable2V3(db, currentVersion);
          await NKNDataManager.upgradeContactSchema2V3(db, currentVersion);
        }
        if (newVersion >= currentVersion) {
          await SubscriberRepo.create(db, currentVersion);
          await BlackListRepo.create(db, currentVersion);
        }
      },
    );
    if (currentVersion < 3) {
      await NKNDataManager.upgradeTopicTable2V3(db, currentVersion);
      await NKNDataManager.upgradeContactSchema2V3(db, currentVersion);
      await SubscriberRepo.create(db, currentVersion);
      await BlackListRepo.create(db, currentVersion);
    }
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
