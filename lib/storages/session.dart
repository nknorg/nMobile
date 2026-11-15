import 'dart:convert';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'contact.dart';
import 'message.dart';
import 'private_group.dart';
import 'topic.dart';

class SessionStorage with Tag {
  // static String get tableName => 'Session';
  static String get tableName => 'session_v7'; // v7

  static SessionStorage instance = SessionStorage();

  Database? get db => dbCommon.database;

  ParallelQueue _queue = dbCommon.sessionQueue;

  static String createSQL = '''
      CREATE TABLE `$tableName` (
        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `target_id` VARCHAR(100),
        `type` INT,
        `last_message_at` BIGINT,
        `last_message_options` TEXT,
        `is_top` BOOLEAN DEFAULT 0,
        `un_read_count` INT,
        `data` TEXT
      )''';

  SessionStorage();

  static create(Database db) async {
    // create table
    await db.execute(createSQL);
    // index
    try {
      await db.execute('CREATE UNIQUE INDEX `index_unique_session_target_id_type` ON `$tableName` (`target_id`, `type`)');
      await db.execute('CREATE INDEX `index_session_is_top_last_message_at` ON `$tableName` (`is_top`, `last_message_at`)');
    } catch (e) {
      if (e.toString().contains("exists") != true) throw e;
    }
  }

  Future<SessionSchema?> insert(SessionSchema? schema, {bool unique = true}) async {
    if (schema == null) return null;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - insert\n - targetId:${schema.targetId}\n - type:${schema.type}\n - lastMessageAt:${schema.lastMessageAt}"); // await
      }
      return null;
    }
    Map<String, dynamic> entity = await schema.toMap();
    return await _queue.add(() async {
      try {
        int? id;
        if (!unique) {
          id = await db?.transaction((txn) {
            return txn.insert(tableName, entity);
          });
        } else {
          id = await db?.transaction((txn) async {
            List<Map<String, dynamic>> res = await txn.query(
              tableName,
              columns: ['*'],
              where: 'target_id = ? AND type = ?',
              whereArgs: [schema.targetId, schema.type],
            );
            if (res != null && res.length > 0) {
              logger.w("$TAG - insert - duplicated - db_exist:${res.first} - insert_new:$schema");
              entity = res.first;
              return null;
            } else {
              return await txn.insert(tableName, entity);
            }
          });
        }
        SessionSchema added = SessionSchema.fromMap(entity);
        if (id != null) added.id = id;
        logger.i("$TAG - insert - success - schema:$added");
        return added;
      } catch (e, st) {
        handleError(e, st);
      }
      return null;
    });
  }

  Future<bool> delete(String? targetId, int? type) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - delete\n - targetId:$targetId\n - type:$type"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? result = await db?.transaction((txn) {
              return txn.delete(
                tableName,
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            if (result != null && result > 0) {
              // logger.v("$TAG - delete - success - targetId:$targetId - type:$type");
              return true;
            }
            // logger.v("$TAG - delete - empty - targetId:$targetId - type:$type");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<SessionSchema?> query(String? targetId, int? type) async {
    if (targetId == null || targetId.isEmpty || type == null) return null;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - query\n - targetId:$targetId\n - type:$type"); // await
      }
      return null;
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          where: 'target_id = ? AND type = ?',
          whereArgs: [targetId, type],
        );
      });
      if (res != null && res.length > 0) {
        SessionSchema schema = SessionSchema.fromMap(res.first);
        // logger.v("$TAG - query - success - targetId:$targetId - type:$type - schema:$schema");
        return schema;
      }
      // logger.v("$TAG - query - empty - targetId:$targetId - type:$type");
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<List<SessionSchema>> queryListRecent({int offset = 0, final limit = 20}) async {
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - queryListRecent"); // await
      }
      return [];
    }
    try {
      List<Map<String, dynamic>>? res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['*'],
          offset: offset,
          limit: limit,
          orderBy: 'is_top DESC, last_message_at DESC',
        );
      });
      if (res == null || res.isEmpty) {
        // logger.v("$TAG - queryListRecent - empty");
        return [];
      }
      List<SessionSchema> result = <SessionSchema>[];
      // String logText = '';
      res.forEach((map) {
        SessionSchema item = SessionSchema.fromMap(map);
        // logText += "\n      $item";
        result.add(item);
      });
      // logger.v("$TAG - queryListRecent - success - length:${result.length} - items:$logText");
      return result;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }

  Future<int> querySumUnReadCount() async {
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - querySumUnReadCount"); // await
      }
      return 0;
    }
    try {
      final res = await db?.transaction((txn) {
        return txn.query(
          tableName,
          columns: ['SUM(un_read_count)'],
        );
      });
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      // logger.v("$TAG - querySumUnReadCount - count:$count");
      return count ?? 0;
    } catch (e, st) {
      handleError(e, st);
    }
    return 0;
  }

  Future<bool> setLastMessageAndUnReadCount(SessionSchema? schema) async {
    if (schema == null || schema.targetId.isEmpty) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - setLastMessageAndUnReadCount\n - targetId:${schema.targetId}\n - type:${schema.type}"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'last_message_at': schema.lastMessageAt,
                  'last_message_options': schema.lastMessageOptions != null ? jsonEncode(schema.lastMessageOptions) : null,
                  'un_read_count': schema.unReadCount,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [schema.targetId, schema.type],
              );
            });
            // logger.v("$TAG - setLastMessageAndUnReadCount - count:$count - schema:$schema");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setTop(String? targetId, int? type, bool isTop) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - setTop\n - targetId:$targetId\n - type:$type\n - isTop:$isTop"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'is_top': isTop ? 1 : 0,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            // logger.v("$TAG - setTop - targetId:$targetId - type:$type - isTop:$isTop");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setUnReadCount(String? targetId, int? type, int unread) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - setUnReadCount\n - targetId:$targetId\n - type:$type\n - unread:$unread"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'un_read_count': unread,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            // logger.v("$TAG - setUnReadCount - targetId:$targetId - type:$type - unread:$unread");
            return (count ?? 0) > 0;
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<bool> setData(String? targetId, int? type, Map<String, dynamic>? newData) async {
    if (targetId == null || targetId.isEmpty || type == null) return false;
    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - setData\n - targetId:$targetId\n - type:$type\n - newData:$newData"); // await
      }
      return false;
    }
    return await _queue.add(() async {
          try {
            int? count = await db?.transaction((txn) {
              return txn.update(
                tableName,
                {
                  'data': newData != null ? jsonEncode(newData) : null,
                },
                where: 'target_id = ? AND type = ?',
                whereArgs: [targetId, type],
              );
            });
            if (count != null && count > 0) {
              // logger.v("$TAG - setData - success - targetId:$targetId - type:$type - data:$newData");
              return true;
            }
            logger.w("$TAG - setData - fail - targetId:$targetId - type:$type - data:$newData");
          } catch (e, st) {
            handleError(e, st);
          }
          return false;
        }) ??
        false;
  }

  Future<List<SessionSchema>> queryListBySearch(String query) async {
    if (query.trim().isEmpty) {
      return await queryListRecent(offset: 0, limit: 1000);
    }

    if (db?.isOpen != true) {
      if (Settings.sentryEnable) {
        Sentry.captureMessage("DB_SESSION CLOSED - queryListBySearch");
      }
      return [];
    }

    try {
      String searchPattern = '%${query.trim()}%';
      String lowerPattern = searchPattern.toLowerCase();
      String lowerQuery = query.trim().toLowerCase();

      // Get all sessions
      List<SessionSchema> allSessions = [];
      int offset = 0;
      const int limit = 100;
      while (true) {
        List<SessionSchema> sessions = await queryListRecent(offset: offset, limit: limit);
        if (sessions.isEmpty) break;
        allSessions.addAll(sessions);
        if (sessions.length < limit) break;
        offset += limit;
      }

      List<SessionSchema> filtered = [];

      for (var session in allSessions) {
        bool matches = false;

        // Check last message content in database
        if (!matches) {
          try {
            List<Map<String, dynamic>>? msgResults = await db?.rawQuery(
              'SELECT * FROM ${MessageStorage.tableName} WHERE target_id = ? AND target_type = ? AND is_delete = 0 AND (LOWER(content) LIKE ? OR LOWER(type) LIKE ?) ORDER BY send_at DESC LIMIT 1',
              [session.targetId, session.type, lowerPattern, lowerPattern],
            );
            if (msgResults != null && msgResults.isNotEmpty) {
              matches = true;
            }
          } catch (e) {
            logger.w("$TAG - queryListBySearch - Search message error: $e");
          }
        }

        // Check contact/topic/group name in database
        if (!matches) {
          if (session.type == SessionType.CONTACT) {
            // Check contact name and address in database
            try {
              List<Map<String, dynamic>>? contactResults = await db?.rawQuery(
                'SELECT * FROM ${ContactStorage.tableName} WHERE address = ? AND (LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(remark_name) LIKE ? OR LOWER(address) LIKE ?) LIMIT 1',
                [session.targetId, lowerPattern, lowerPattern, lowerPattern, lowerPattern, lowerPattern],
              );
              if (contactResults != null && contactResults.isNotEmpty) {
                matches = true;
              } else {
                // Fallback to targetId
                if (session.targetId.toLowerCase().contains(lowerQuery)) {
                  matches = true;
                }
              }
            } catch (e) {
              logger.w("$TAG - queryListBySearch - Search contact error: $e");
              // Fallback to targetId
              if (session.targetId.toLowerCase().contains(lowerQuery)) {
                matches = true;
              }
            }
          } else if (session.type == SessionType.TOPIC) {
            // Check topic name in database
            try {
              List<Map<String, dynamic>>? topicResults = await db?.rawQuery(
                'SELECT * FROM ${TopicStorage.tableName} WHERE topic_id = ? AND LOWER(topic_id) LIKE ? LIMIT 1',
                [session.targetId, lowerPattern],
              );
              if (topicResults != null && topicResults.isNotEmpty) {
                matches = true;
              } else {
                // Fallback to targetId
                if (session.targetId.toLowerCase().contains(lowerQuery)) {
                  matches = true;
                }
              }
            } catch (e) {
              logger.w("$TAG - queryListBySearch - Search topic error: $e");
              // Fallback to targetId
              if (session.targetId.toLowerCase().contains(lowerQuery)) {
                matches = true;
              }
            }
          } else if (session.type == SessionType.PRIVATE_GROUP) {
            // Check group name in database
            try {
              List<Map<String, dynamic>>? groupResults = await db?.rawQuery(
                'SELECT * FROM ${PrivateGroupStorage.tableName} WHERE group_id = ? AND LOWER(name) LIKE ? LIMIT 1',
                [session.targetId, lowerPattern],
              );
              if (groupResults != null && groupResults.isNotEmpty) {
                matches = true;
              } else {
                // Fallback to targetId
                if (session.targetId.toLowerCase().contains(lowerQuery)) {
                  matches = true;
                }
              }
            } catch (e) {
              logger.w("$TAG - queryListBySearch - Search group error: $e");
              // Fallback to targetId
              if (session.targetId.toLowerCase().contains(lowerQuery)) {
                matches = true;
              }
            }
          }
        }

        if (matches) {
          filtered.add(session);
        }
      }

      // Sort filtered results
      filtered.sort((a, b) => a.isTop ? (b.isTop ? (b.lastMessageAt).compareTo((a.lastMessageAt)) : -1) : (b.isTop ? 1 : b.lastMessageAt.compareTo(a.lastMessageAt)));

      return filtered;
    } catch (e, st) {
      handleError(e, st);
    }
    return [];
  }
}
