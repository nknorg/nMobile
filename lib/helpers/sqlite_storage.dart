import 'package:flutter/material.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SqliteStorage {
  static const String CHAT_DATABASE_NAME = 'nkn';
  Database db;
  SqliteStorage({this.db});

  static Future<Database> open(String name, String password) async {
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
        var publicKey = name.replaceFirst(SqliteStorage.CHAT_DATABASE_NAME + '_', '');
        var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(publicKey);
        await db.insert(
            ContactSchema.tableName,
            ContactSchema(
              type: ContactType.me,
              clientAddress: name.replaceFirst(SqliteStorage.CHAT_DATABASE_NAME + '_', ''),
              nknWalletAddress: walletAddress,
              createdTime: now,
              updatedTime: now,
              profileVersion: uuid.v4(),
            ).toEntity());

        await TopicSchema.create(db, version);
        await SubscribersSchema.create(db, version);
      },
    );
    return db;
  }

  static Future delete(String name) async {
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
