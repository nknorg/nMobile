import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:synchronized/synchronized.dart';

// TODO:GG PG check
class PrivateGroupStorage with Tag {
  static String get tableName => 'PrivateGroup';

  Database? get db => dbCommon.database;
  Lock _lock = new Lock();

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `group_id` VARCHAR(100),
        `name` VARCHAR(200),
        `avatar` TEXT,
        `version` TEXT,
        `count` INT,
        `is_top` BOOLEAN DEFAULT 0,
        `options` TEXT,
        `create_at` BIGINT,
        `update_at` BIGINT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE UNIQUE INDEX `index_unique_private_group_group_id` ON `$tableName` (`group_id`)');
    await db.execute('CREATE INDEX `index_private_group_name` ON `$tableName` (`name`)');
    await db.execute('CREATE INDEX `index_private_group_version` ON `$tableName` (`version`)');
    await db.execute('CREATE INDEX `index_private_group_create_at` ON `$tableName` (`create_at`)');
    await db.execute('CREATE INDEX `index_private_group_update_at` ON `$tableName` (`update_at`)');
  }

  Future<PrivateGroupSchema?> insert(PrivateGroupSchema schema) async {
    Map<String, dynamic> entity = schema.toMap();
    try {
      int? id = await db?.insert(tableName, entity);

      if (id != null && id > 0) {
        schema.id = id;
        logger.v("$TAG - insert - success - schema:$schema");
        return schema;
      }
      logger.w("$TAG - insert - empty - schema:$schema");
    } catch (e, st) {
      if (e.toString().contains('UNIQUE constraint failed: PrivateGroup.group_id')) {
      } else {
        handleError(e, st);
      }
    }
    return null;
  }

  Future<PrivateGroupSchema?> query(String groupId) async {
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'group_id = ?',
          whereArgs: [groupId],
          offset: 0,
          limit: 1,
        );
      });
      if (res != null && res.length > 0) {
        PrivateGroupSchema? schema = PrivateGroupSchema.fromMap(res.first);
        logger.v("$TAG - query - success - groupId:$groupId - schema:$schema");
        return schema;
      }
      logger.v("$TAG - query - empty - groupId:$groupId");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<bool> setAvatar(String groupId, String? avatarLocalPath) async {
    if (db?.isOpen != true) return false;
    return await _lock.synchronized(() async {
      try {
        int? count = await db?.transaction((txn) {
          return txn.update(
            tableName,
            {
              'avatar': avatarLocalPath,
              'update_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'group_id = ?',
            whereArgs: [groupId],
          );
        });
        if (count != null && count > 0) {
          logger.v("$TAG - setAvatar - success - groupId:$groupId - avatarLocalPath:$avatarLocalPath");
          return true;
        }
        logger.w("$TAG - setAvatar - fail - groupId:$groupId - avatarLocalPath:$avatarLocalPath");
      } catch (e, st) {
        handleError(e, st);
      }
      return false;
    });
  }

  Future<bool> update(String groupId, PrivateGroupSchema schema) async {
    Map<String, dynamic> model = schema.toMap();
    model.remove('id');
    model.remove('create_at');
    model['update_at'] = DateTime.now().millisecondsSinceEpoch;

    model.removeWhere((key, value) => value == null);
    try {
      int? count = await db?.update(
        tableName,
        model,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      return count != null && count > 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return false;
  }

  Future<int?> delete() async {
    if (db?.isOpen != true) return null;

    try {
      int? res = await db?.transaction((txn) {
        return txn.delete(tableName);
      });
      return res;
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<void> dropTable() async {
    try {
      await db?.execute('DROP TABLE $tableName');
    } catch (e, st) {
      handleError(e, st);
    }
  }
}
