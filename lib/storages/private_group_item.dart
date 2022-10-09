import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class PrivateGroupItemStorage with Tag {
  static String get tableName => 'PrivateGroupList';

  static PrivateGroupItemStorage instance = PrivateGroupItemStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = ParallelQueue("storage_private_group_item", onLog: (log, error) => error ? logger.w(log) : null);

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `group_id` VARCHAR(200),
        `permission` INT,
        `expires_at` BIGINT,
        `inviter` VARCHAR(200),
        `invitee` VARCHAR(200),
        `inviter_raw_data` TEXT,
        `invitee_raw_data` TEXT,
        `inviter_signature` VARCHAR(200),
        `invitee_signature` VARCHAR(200),
        `data` TEXT
      )''';

  static create(Database db) async {
    // create table
    await db.execute(createSQL);

    // index
    await db.execute('CREATE UNIQUE INDEX `index_private_group_item_group_id_invitee` ON `$tableName` (`group_id`, `invitee`)');
    await db.execute('CREATE INDEX `index_private_group_item_group_id_expires_at` ON `$tableName` (`group_id`, `expires_at`)');
    await db.execute('CREATE INDEX `index_private_group_item_group_id_permission_expires_at` ON `$tableName` (`group_id`, `permission`, `expires_at`)');
  }

  Future<PrivateGroupItemSchema?> insert(PrivateGroupItemSchema? schema) async {
    if (db?.isOpen != true) return null;
    if (schema == null || schema.groupId.isEmpty) return null;
    Map<String, dynamic> entity = schema.toMap();
    return await _queue.add(() async {
      try {
        int? id = await db?.transaction((txn) {
          return txn.insert(tableName, entity);
        });
        if (id != null) {
          PrivateGroupItemSchema schema = PrivateGroupItemSchema.fromMap(entity);
          schema.id = id;
          logger.v("$TAG - insert - success - schema:$schema");
          return schema;
        } else {
          logger.i("$TAG - insert - fail - schema:$schema");
        }
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<PrivateGroupItemSchema?> queryByInvitee(String? groupId, String? invitee) async {
    if (db?.isOpen != true) return null;
    if (groupId == null || groupId.isEmpty || invitee == null || invitee.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'group_id = ? AND invitee = ?',
        whereArgs: [groupId, invitee],
        offset: 0,
        limit: 1,
      );
      if (res != null && res.length > 0) {
        PrivateGroupItemSchema? schema = PrivateGroupItemSchema.fromMap(res.first);
        logger.v("$TAG - queryByInvitee - success - invitee:$invitee - schema:$schema");
        return schema;
      }
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<PrivateGroupItemSchema>> queryList(String? groupId, {int? perm, int offset = 0, int limit = 20}) async {
    if (db?.isOpen != true) return [];
    if (groupId == null || groupId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: perm != null ? 'group_id = ? AND permission = ?' : 'group_id = ?',
          whereArgs: perm != null ? [groupId, perm] : [groupId],
          offset: offset,
          limit: limit,
          orderBy: 'expires_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        logger.v("$TAG - queryList - empty - groupId:$groupId");
        return [];
      }
      List<PrivateGroupItemSchema> results = <PrivateGroupItemSchema>[];
      String logText = '';
      res.forEach((map) {
        logText += "\n      $map";
        PrivateGroupItemSchema pgItem = PrivateGroupItemSchema.fromMap(map);
        results.add(pgItem);
      });
      logger.v("$TAG - queryList - items:$logText");
      return results;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<bool> updatePermission(
    String? groupId,
    String? invitee,
    int? permission,
    int? expiresAt,
    String? inviterRawData,
    String? inviteeRawData,
    String? inviterSignature,
    String? inviteeSignature,
  ) async {
    if (db?.isOpen != true) return false;
    if (groupId == null || groupId.isEmpty || invitee == null || invitee.isEmpty) return false;
    if (permission == null) return false;
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'permission': permission,
                  'expires_at': expiresAt,
                  'inviter_raw_data': inviterRawData,
                  'invitee_raw_data': inviteeRawData,
                  'inviter_signature': inviterSignature,
                  'invitee_signature': inviteeSignature,
                  'update_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'group_id = ? AND invitee = ?',
                whereArgs: [groupId, invitee],
              );
            });
            if (count != null && count > 0) {
              logger.v("$TAG - updatePermission - success - groupId:$groupId - invitee:$invitee - type:$permission");
              return true;
            }
            logger.w("$TAG - updatePermission - fail - groupId:$groupId - invitee:$invitee - type:$permission");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }
}
