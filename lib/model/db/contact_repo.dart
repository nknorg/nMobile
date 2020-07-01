import 'package:sqflite_sqlcipher/sqflite.dart';

// fixme: to be improved
class ContactRepo {
  Database _db;

  ContactRepo(Database db) {
    _db = db;
  }
}
