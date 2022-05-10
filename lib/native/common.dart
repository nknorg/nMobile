import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:uuid/uuid.dart';

class Common {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.mobile/native/common_method');
  static const EventChannel _eventChannel = EventChannel('org.nkn.mobile/native/common_event');

  static install() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (!(event is Map)) return;
      String? name = event["event"];
      if (name == null || name.isEmpty) return;
      switch (name) {
        case "onDeviceTokenRefresh":
          String? token = event["result"];
          logger.i("Common - onDeviceTokenRefresh - token:$token");
          // need refresh profileVersion, but here no version judge diff, just expire
          break;
        case "onRemoteMessageReceived":
          bool? isApplicationForeground = event["isApplicationForeground"];
          String title = event["title"] ?? Global.locale((s) => s.new_message);
          String content = event["content"] ?? Global.locale((s) => s.you_have_new_message);
          logger.i("Common - onRemoteMessageReceived - isApplicationForeground:$isApplicationForeground - title:$title - content:$content");
          if (!(isApplicationForeground ?? true)) {
            localNotification.show(Uuid().v4(), title, content);
          }
          break;
      }
    });
  }

  static Future<bool> backDesktop() async {
    try {
      await _methodChannel.invokeMethod('backDesktop');
      return true;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<bool> saveMediaToGallery(Uint8List imageData, String imageName, String albumName) async {
    try {
      await _methodChannel.invokeMethod('saveImageToGallery', {
        'imageData': imageData,
        'imageName': imageName,
        'albumName': albumName,
      });
      return true;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<String?> getAPNSToken() async {
    try {
      final Map resp = await _methodChannel.invokeMethod('getAPNSToken', {});
      return resp['token'];
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  static Future<bool> sendPushAPNS(String deviceToken, String pushPayload) async {
    try {
      await _methodChannel.invokeMethod('sendPushAPNS', {
        'deviceToken': deviceToken,
        'pushPayload': pushPayload,
      });
      return true;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<bool> isGoogleServiceAvailable() async {
    try {
      final Map resp = await _methodChannel.invokeMethod('isGoogleServiceAvailable', {});
      return resp['availability'] ?? false;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<String?> getFCMToken() async {
    try {
      final Map resp = await _methodChannel.invokeMethod('getFCMToken', {});
      return resp['token'];
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  static Future<bool> updateBadgeCount(int count) async {
    try {
      await _methodChannel.invokeMethod('updateBadgeCount', {
        'badge_count': count,
      });
      return true;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  static Future<List<Object?>> splitPieces(String dataBytesString, int dataShards, int parityShards) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('splitPieces', {
        'data': dataBytesString,
        'dataShards': dataShards,
        'parityShards': parityShards,
      });
      return resp['data'] ?? [];
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  static Future<String?> combinePieces(List<Uint8List> dataList, int dataShards, int parityShards, int bytesLength) async {
    try {
      final Map resp = await _methodChannel.invokeMethod('combinePieces', {
        'data': dataList,
        'dataShards': dataShards,
        'parityShards': parityShards,
        'bytesLength': bytesLength,
      });
      return resp['data'];
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  /*static Future<bool?> resetSQLitePasswordInIos(String dbPath, String dbPwd, {bool readOnly = false}) async {
    if (!Platform.isIOS) return false;
    try {
      final Map resp = await _methodChannel.invokeMethod('resetSQLitePassword', {
        'path': dbPath,
        'password': dbPwd,
        'readOnly': readOnly,
      });
      return resp['success'];
    } catch (e) {
      handleError(e);
    }
  }*/
}
