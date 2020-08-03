import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class CdnMiner {
  String nshId;
  String _name;
  Map<String, dynamic> data;
  bool status;

  num flow;
  num cost;
  num contribution;

  CdnMiner(this.nshId, {String name, this.flow, this.cost, this.contribution}) {
    if (nshId.contains('ctrl.')) {
      nshId = nshId.split('ctrl.')[1];
    }
    if (name == null || name.length == 0) {
      if(nshId.length > 8) {
        _name = nshId.substring(0, 8);
      } else {
        _name = nshId;
      }
    } else {
      _name = name;
    }
  }

  String get name {
    if (_name == null || _name.length == 0) {
      _name = nshId.substring(0, 8);
    }
    return _name;
  }

  set name(String name) {
    _name = name;
  }

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
    if (_name == null) {
      _name = nshId.substring(0, 8);
    }
    Map<String, dynamic> map = {
      'nsh_id': nshId,
      'name': _name,
      'data': data,
    };
    return map;
  }

  static Future<List<CdnMiner>> getAllCdnMiner() async {
    try {
      Database db = SqliteStorage(db: Global.currentCDNDb).db;
      var res = await db.query(
        CdnMiner.tableName,
        columns: ['*'],
      );

      return res.map((x) => parseEntity(x)).toList();
    } catch (e) {
      NLog.v(e, tag: 'getAllCdnMiner');
      return <CdnMiner>[];
    }
  }

  String getStatus() {
    if (data == null || data.length == 0) return '未知';
    try {
      if (data['Result']) {
        return '运行中';
      } else {
        return '异常';
      }
    } catch (e) {
      NLog.v(e, tag: 'getStatus');
      return '未知';
    }
  }

  Color getStatusColor() {
    if (getStatus() == '运行中') {
      return DefaultTheme.notificationBackgroundColor;
    } else if (getStatus() == '未知') {
      return DefaultTheme.fontColor2;
    } else {
      return DefaultTheme.fallColor;
    }
  }

  static CdnMiner parseEntity(Map e) {
    try {
      var c = CdnMiner(e['nsh_id']);
      if (e.containsKey('name') && e['name'].toString().length > 0) {
        c._name = e['name'];
      } else {
        c._name = c.nshId.substring(0, 8);
      }
//      c.flow = num.parse(e['flow']);
//      c.cost = num.parse(e['cost']);
//      c.contribution = num.parse(e['contribution']);
      try {
        if (e['data'] != null) {
//          LogUtil.v(e['data']);
          c.data = jsonDecode(e['data']);
//          c.data = jsonDecode(e['data']);
        }
      } catch (e) {
        NLog.v(e, tag: 'CdnMinerparseEntity');
      }
      return c;
    } catch (e) {
      NLog.v(e, tag: 'CdnMiner parseEntity');
      return null;
    }
  }

  Future<bool> insertOrUpdate() async {
    try {
      Database db = SqliteStorage(db: Global.currentCDNDb).db;
      var countQuery = await db.query(
        CdnMiner.tableName,
        columns: ['*'],
        where: 'nsh_id = ?',
        whereArgs: [nshId],
      );
      if (countQuery == null || countQuery.length == 0) {
        int n = await db.insert(CdnMiner.tableName, toEntity());
        return n > 0;
      } else {
        if (_name == null) {
          _name = nshId.substring(0, 8);
        }
        var map = {'name': _name};
        map['data'] = (data != null ? jsonEncode(data) : null);
        int n = await db.update(
          CdnMiner.tableName,
          map,
          where: 'nsh_id = ?',
          whereArgs: [nshId],
        );
        return n > 0;
      }
    } catch (e) {
      NLog.e(e.toString());
      return false;
    }
  }

  static Future<CdnMiner> getModelFromNshid(String nshid) async {
    try {
      if (nshid.contains('ctrl.')) {
        nshid = nshid.split('ctrl.')[1];
      }
      Database db = SqliteStorage(db: Global.currentCDNDb).db;
      var res = await db.query(
        CdnMiner.tableName,
        columns: ['*'],
        where: 'nsh_id = ?',
        whereArgs: [nshid],
      );
      if (res.length == 0) return null;
      return res.map((x) => parseEntity(x)).toList()[0];
    } catch (e) {
      NLog.v(e, tag: 'getModelFromNshid');
      return null;
    }
  }

  Future<int> insert() async {
    try {
      Database db = SqliteStorage(db: Global.currentCDNDb).db;
      int id = await db.insert(CdnMiner.tableName, toEntity());
      return id;
    } catch (e) {
      NLog.v(e, tag: 'insert');
      debugPrint(e);
      debugPrintStack();
    }
  }

  String getIp() {
    try {
      if (data != null) {
        return data['Details']['internal_ip'];
      }
      return '';
    } catch (e) {
      NLog.v(e, tag: 'getIp');
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

  delete() {
    Database db = SqliteStorage(db: Global.currentCDNDb).db;
    db.delete(
      CdnMiner.tableName,
      where: 'nsh_id = ?',
      whereArgs: [nshId],
    );
  }

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

  reboot() {
    MessageSchema msg = MessageSchema();
    msg.content = 'reboot';
    NknClientPlugin.sendText(['ctrl.$nshId'], msg.toTextData(), maxHoldingSeconds: 1);
  }

  getMinerDetail() {
    MessageSchema msg = MessageSchema();
    msg.content = '/usr/bin/self_checker.sh';
    NknClientPlugin.sendText(['ctrl.$nshId'], msg.toTextData());
  }

  static removeCacheData() async {
    List<CdnMiner> _miner = await getAllCdnMiner();
    for (var value in _miner) {
      value.data = null;
      await value.insertOrUpdate();
    }
  }
}
