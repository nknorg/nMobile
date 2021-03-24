import 'dart:convert';
import 'dart:io';

import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ContactType {
  static const String stranger = 'stranger';
  static const String friend = 'friend';
  static const String me = 'me';
}

class RequestType {
  static const String header = 'header';
  static const String full = 'full';
}

class ContactDataCenter {
  static Duration contactRequestGap = Duration(minutes: 3);
  static Duration contactResponseFullGap = Duration(seconds: 10);

  static setOrUpdateProfileVersion(
      ContactSchema otherContact, Map<String, dynamic> updateInfo) async {
    Database cdb = await NKNDataManager().currentDatabase();

    var res = await cdb.query(
      ContactSchema.tableName,
      columns: ['*'],
      where: 'id = ?',
      whereArgs: [otherContact.id],
    );

    var record = res?.first;

    String receivedVersion = '';
    if (record != null) {
      var content = updateInfo['content'];

      /// only when received contact.header and profileVersion is not match
      receivedVersion = updateInfo['version'];

      if (compareProfileVersion(otherContact.profileVersion, receivedVersion) ==
          false) {
        ContactDataCenter.requestProfile(otherContact, RequestType.full);
      }
      if (receivedVersion != null) {
        otherContact.setProfileVersion(receivedVersion);
      }
    }
  }

  static Future<bool> saveRemarkProfile(
      ContactSchema profile, Map profileInfo) async {
    Map dataInfo = Map<String, dynamic>();
    if (profile.extraInfo != null) {
      dataInfo = profile.extraInfo;
    }

    if (profileInfo['first_name'] != null) {
      dataInfo['remark_name'] = profileInfo['first_name'];
    }

    if (profileInfo['avatar'] != null) {
      String remarkPath = 'remark_' + profile.clientAddress;
      String filePath = getLocalContactPath(remarkPath, profileInfo['avatar']);
      dataInfo['remark_avatar'] = filePath;
    }

    Map saveDataInfo = Map<String, dynamic>();
    saveDataInfo['data'] = jsonEncode(dataInfo);

    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      ContactSchema.tableName,
      saveDataInfo,
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    if (count > 0) {
      NLog.w('saveRemarkProfile Success___' + dataInfo.toString());
      return true;
    }
    NLog.w('saveRemarkProfile Failed___' + dataInfo.toString());
    return false;
  }

  static Future<bool> saveProfile(
      ContactSchema profile, Map profileInfo) async {
    Map saveDataInfo = Map<String, dynamic>();

    NLog.w(
        'saveProfile Before avatar is____' + profileInfo['avatar'].toString());
    if (profileInfo['avatar'] != null) {
      String filePath = getLocalContactPath(
          NKNClientCaller.currentChatId, profileInfo['avatar']);
      saveDataInfo['avatar'] = filePath;
      NLog.w('saveProfile avatar avatar isPath____' +
          profileInfo['avatar'].toString());
    }
    if (profileInfo['first_name'] != null) {
      saveDataInfo['first_name'] = profileInfo['first_name'];
    }
    if (profileInfo['profile_expires_at'] != null) {
      saveDataInfo['profile_expires_at'] = profileInfo['profile_expires_at'];
    }

    saveDataInfo['updated_time'] = DateTime.now().millisecondsSinceEpoch;

    Map hashCodeMap = Map<String, dynamic>();
    if (profileInfo['first_name'] != null) {
      hashCodeMap['first_name'] = profileInfo['first_name'];
    }
    if (profileInfo['avatar'] != null) {
      File avatarFile = File(profileInfo['avatar']);
      if (avatarFile != null) {
        hashCodeMap['avatar'] = avatarFile.hashCode;
      }
    }

    if (hashCodeMap.length > 0) {
      saveDataInfo['profile_version'] = hashCodeMap.hashCode;
    }

    Database cdb = await NKNDataManager().currentDatabase();
    var count = await cdb.update(
      ContactSchema.tableName,
      saveDataInfo,
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    if (count > 0) {
      NLog.w('UpdateInfo Success___' + saveDataInfo.toString());
      return true;
    }
    NLog.w('UpdateInfo Failed___' + saveDataInfo.toString());
    return false;
  }

  static bool compareProfileVersion(String aVersion, String bVersion) {
    if (aVersion == null || bVersion == null) {
      return false;
    }
    if (aVersion.length == 0 || bVersion.length == 0) {
      return false;
    }
    return (aVersion == bVersion);
  }

  static Future requestProfile(
      ContactSchema otherContact, String requestType) async {
    /// If requestTime permits
    String msgId = uuid.v4();
    Map data = {
      'id': msgId,
      'contentType': ContentType.contact,
      'requestType': requestType,
      'version': otherContact.profileVersion,
      'expiresAt': 0,
    };

    /// not request profile judge
    try {
      NKNClientCaller.sendText(
          [otherContact.clientAddress], jsonEncode(data), msgId);
      otherContact.profileExpiresAt = DateTime.now();
      otherContact.updateExpiresAtTime();

      NLog.w('requestProfile send___' + data.toString());
    } catch (e) {
      NLog.w('Wrong!!!' + e.toString());
    }
  }

  static responseHeaderProfile(
      ContactSchema otherContact, Map requestInfo) async {
    ContactSchema meMyself = await ContactSchema.fetchCurrentUser();
    String msgId = uuid.v4();
    Map data = {
      'id': msgId,
      'contentType': ContentType.contact,
      'version': meMyself.profileVersion,
      'responseType': RequestType.header,
      'expiresAt': 0,
    };
    data['onePieceReady'] = '1';

    try {
      NKNClientCaller.sendText(
          [otherContact.clientAddress], jsonEncode(data), msgId);
    } catch (e) {
      NLog.w("Wrong!!! responseHeaderProfile__" + e.toString());
    }
    NLog.w('ResponseType__Header____' + DateTime.now().toString());
  }

  static responseFullProfile(
      ContactSchema otherContact, Map requestInfo) async {
    ContactSchema meMyself = await ContactSchema.fetchCurrentUser();
    String msgId = uuid.v4();
    Map data = {
      'id': msgId,
      'contentType': ContentType.contact,
      'version': meMyself.profileVersion,
      'responseType': RequestType.full,
      'expiresAt': 0,
    };
    if (Platform.isIOS) {
      data['onePieceReady'] = '1';
    }
    try {
      Map<String, dynamic> content = {
        'name': meMyself.firstName,
      };
      if (meMyself?.avatar != null) {
        bool exitsAvatar = meMyself.avatar.existsSync();
        if (exitsAvatar == false) {
          NLog.w('Wrong!!!!__avatar is not exist');
          return;
        }
        content['avatar'] = {
          'type': 'base64',
          'data': base64Encode(meMyself.avatar.readAsBytesSync()),
        };
      }
      data['content'] = content;
    } catch (e) {
      NLog.w('Wrong!!! toResponseData__' + e.toString());
    }
    try {
      NKNClientCaller.sendText(
          [otherContact.clientAddress], jsonEncode(data), msgId);
    } catch (e) {
      NLog.w("Wrong!!! responseFullProfile__" + e.toString());
    }
    int responseTimeValue = DateTime.now().millisecondsSinceEpoch;
    String responseTimeKey =
        LocalStorage.NKN_USER_PROFILE_VERSION_RESPONSE_TIME +
            otherContact.clientAddress;
    LocalStorage().set(responseTimeKey, responseTimeValue);
  }

  static Future meResponseToProfile(
      ContactSchema otherContact, Map requestInfo) async {
    // bool canResponseFull = false;
    String responseType = RequestType.header;
    ContactSchema meMyself = await ContactSchema.fetchCurrentUser();

    if (meMyself.profileVersion == null) {
      NLog.w('!!!!!!!!!!!!meMyself.profileVersion is null');
    }
    if (compareProfileVersion(
            requestInfo['version'], meMyself.profileVersion) ==
        false) {
      if (requestInfo['requestType'] == RequestType.header) {
        responseHeaderProfile(otherContact, requestInfo);
        return;
      }
    }
    if (requestInfo['requestType'] == RequestType.header) {
      responseHeaderProfile(otherContact, requestInfo);
      return;
    }
    //todo can cache to memory if possible.
    String responseTimeKey =
        LocalStorage.NKN_USER_PROFILE_VERSION_RESPONSE_TIME +
            otherContact.clientAddress;
    int responseTime = await LocalStorage().get(responseTimeKey);

    if (responseTime == null) {
      responseFullProfile(otherContact, requestInfo);
    } else {
      DateTime beforeTime = DateTime.now().subtract(contactResponseFullGap);
      DateTime responseTimeExpire =
          DateTime.fromMillisecondsSinceEpoch(responseTime);
      NLog.w('responseTimeExpire is____' + responseTimeExpire.toString());
      if (responseTimeExpire.isBefore(beforeTime)) {
        responseFullProfile(otherContact, requestInfo);
      }
    }
  }
}
