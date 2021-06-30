import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

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
          // TODO:GG refresh profileVersion
          break;
        case "onRemoteMessageReceived":
          bool? isApplicationForeground = event["isApplicationForeground"];
          String? title = event["title"];
          String? content = event["content"];
          logger.i("Common - onRemoteMessageReceived - isApplicationForeground:$isApplicationForeground - title:$title - content:$content");
          if (!(isApplicationForeground ?? true)) {
            // TODO:GG show localNotification
          }
          break;
      }
    });
  }

  static Future<bool> backDesktop() async {
    try {
      await _methodChannel.invokeMethod('backDesktop');
    } catch (e) {
      logger.e(e);
    }
    return false;
  }

  static Future sendPushAPNS(String deviceToken, String pushPayload) async {
    try {
      await _methodChannel.invokeMethod('sendPushAPNS', {
        'deviceToken': deviceToken,
        'pushPayload': pushPayload,
      });
    } catch (e) {
      throw e;
    }
  }

  static Future<bool> isGoogleServiceAvailable() async {
    try {
      final Map resp = await _methodChannel.invokeMethod('isGoogleServiceAvailable', {});
      return resp['availability'] ?? false;
    } catch (e) {
      throw e;
    }
  }

  static Future<String?> getFCMToken() async {
    try {
      final Map resp = await _methodChannel.invokeMethod('getFCMToken', {});
      return resp['token'];
    } catch (e) {
      throw e;
    }
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
      throw e;
    }
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
      throw e;
    }
  }
}
