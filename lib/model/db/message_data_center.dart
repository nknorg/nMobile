

import 'dart:typed_data';

import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageDataCenter{
  static updateMessagePid(Uint8List pid,String msgId) async{
    Database cdb = await NKNDataManager().currentDatabase();
    int result = await cdb.update(
      MessageSchema.tableName,
      {
        'pid': pid != null ? hexEncode(pid) : null,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    if (result > 0){
      NLog.w('updatePid success!__'+msgId.toString());
    }
    else{
      NLog.w('Wrong!!! updatePid Failed!!!'+msgId.toString());
      NLog.w('Wrong!!! updatePid Failed!!!'+result.toString());
    }
  }

  static Future<bool> judgeMessagePid(String msgId) async{
    Database cdb = await NKNDataManager().currentDatabase();

    var res = await cdb.query(
      MessageSchema.tableName,
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );

    if (res != null && res.length > 0){
      MessageSchema message = MessageSchema.parseEntity(res.first);
      if (message.pid != null && message.pid.length > 0){
        return true;
      }
    }
    return null;
  }
}