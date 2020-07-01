import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SqliteStorage {
  static const String _CHAT_DATABASE_NAME = 'nkn';

  final String name;
  final String _password;
  Database _db;

  SqliteStorage(String publicKey, String password)
      : name = publicKey2DbName(publicKey),
        _password = password;

  Future<Database> get db async {
    _db ??= await _open(name, _password);
    return _db;
  }

  close() async {
    _db?.close();
    _db = null;
  }

  delete() async {
    _delete(name);
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
      version: 2,
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

        await TopicSchema.create(db, version);
        await SubscribersSchema.create(db, version);
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
