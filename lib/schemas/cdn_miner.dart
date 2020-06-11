import 'dart:convert';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/plugins/nshell_client.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class CdnMiner {
  String nshId;
  String name;
  Map<String, dynamic> data;
  bool status;

  num flow;
  num cost;
  num contribution;

  CdnMiner(this.nshId, {String name = '', this.flow, this.cost, this.contribution}) {
    if (nshId.contains('ctrl.')) {
      nshId = nshId.split('ctrl.')[1];
    }
    if (name == null) {
      name = nshId.substring(0, 8);
    }
  }

  static String getName() {}

  static String get tableName => 'Nodes';

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE Nodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nsh_id TEXT,
        name TEXT,
        data TEXT
      )''');
    // index
    await db.execute('CREATE INDEX nsh_id ON Nodes (nsh_id)');
  }

  toEntity() {
    if (name == null) {
      name = nshId.substring(0, 8);
    }
    Map<String, dynamic> map = {
      'nsh_id': nshId,
      'name': name,
      'data': data,
    };
    return map;
  }

  static Future<List<CdnMiner>> getAllCdnMiner() async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
        CdnMiner.tableName,
        columns: ['*'],
      );

      return res.map((x) => parseEntity(x)).toList();
    } catch (e) {
      LogUtil.v(e, tag: 'getAllCdnMiner');
      return <CdnMiner>[];
    }
  }

  String getStatus() {
    if (data == null || data.length == 0) return '未知';
    try {
      if (data['Result']) {
        return '运行中';
      } else {
        return '故障';
      }
    } catch (e) {
      LogUtil.v(e);
      return '未知';
    }
  }

  static CdnMiner parseEntity(Map e) {
    try {
      var c = CdnMiner(e['nsh_id']);
      if (e.containsKey('name') && e['name'].toString().length > 0) {
        c.name = e['name'];
      } else {
        c.name = c.nshId.substring(0, 8);
      }
//      c.flow = num.parse(e['flow']);
//      c.cost = num.parse(e['cost']);
//      c.contribution = num.parse(e['contribution']);
      try {
        if (e['data'] != null) {
          c.data = jsonDecode(e['data']);
//          c.data = jsonDecode(e['data']);
        }
      } catch (e) {
        LogUtil.v(e, tag: 'CdnMiner parseEntity');
        LogUtil.v(e);
      }
      return c;
    } catch (e) {
      LogUtil.v(e, tag: 'CdnMiner parseEntity');
      return null;
    }
  }

  Future<bool> insertOrUpdate() async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var countQuery = await db.query(
        CdnMiner.tableName,
        columns: ['*'],
        where: 'nsh_id = ?',
        whereArgs: [nshId],
      );
      if (countQuery.length == 0) {
        int n = await db.insert(CdnMiner.tableName, toEntity());
        return n > 0;
      } else {
        if (name == null) {
          name = nshId.substring(0, 8);
        }
        var map = {'name': name};
        if (data != null) {
          map['data'] = (data != null ? jsonEncode(data) : null);
        }

        int n = await db.update(
          CdnMiner.tableName,
          map,
          where: 'nsh_id = ?',
          whereArgs: [nshId],
        );
        return n > 0;
      }
    } catch (e) {
      LogUtil.e(e.toString(), tag: 'CDN insertOrUpdate');
      return false;
    }
  }

  static Future<CdnMiner> getModelFromNshid(String nshid) async {
    try {
      if (nshid.contains('ctrl.')) {
        nshid = nshid.split('ctrl.')[1];
      }
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      var res = await db.query(
        CdnMiner.tableName,
        columns: ['*'],
        where: 'nsh_id = ?',
        whereArgs: [nshid],
      );
      if (res.length == 0) return null;
      return res.map((x) => parseEntity(x)).toList()[0];
    } catch (e) {
      LogUtil.v(e, tag: 'getModelFromNshid');
      return null;
    }
  }

  Future<int> insert() async {
    try {
      Database db = SqliteStorage(db: Global.currentChatDb).db;
      int id = await db.insert(CdnMiner.tableName, toEntity());
      return id;
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  getData() {
    MessageSchema msg = MessageSchema();
    msg.content = '/usr/bin/self_checker.sh';
//    NShellClientPlugin.sendText(['ctrl.e39e05bdf29ab3b753ed0aaf7ebdb40533e14fddd25a20ebaee989db5bc32ef6'], msg.toTextData());
    NShellClientPlugin.sendText(['ctrl.$nshId'], msg.toTextData());
  }

  String getIp() {
    try {
      if (data != null) {
        return data['Details']['internal_ip'];
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  String getMacAddress() {
    try {
      if (data != null) {
        return data['Details']['mac_addr'];
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  delete() {}

  String getUsed() {
    try {
      if (data != null) {
        return data['Details']['used'];
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  String getCapacity() {
    try {
      if (data != null) {
        return data['Details']['capacity'];
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
