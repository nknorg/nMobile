/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:sqflite_sqlcipher/sqflite.dart';

/// @author Chenai
/// @version 1.0, 03/07/2020
// fixme: to be improved
class ContactRepo {
  final ContactDao _dao;

  ContactRepo(this._dao);
}

class Contact {
  int id;
  String type;
  String walletAddr;
  String chatId;
  String name;
  String avatarUri;
  // ...
}

class ContactDao {
  final Database _db;

  ContactDao(this._db);

//  @Query("SELECT * from contact WHERE chat_id = :chatId")
  List<Contact> getContactByChatId(String chatId) {
    return null; // TODO
  }
}
