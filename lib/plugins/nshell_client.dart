import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/schemas/cdn_miner.dart';

class NShellClientPlugin {
  static const String TAG = 'NShellClientPlugin';
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/nshellclient');
  static const EventChannel _eventChannel = EventChannel('org.nkn.sdk/nshellclient/event');
  static final CDNBloc _cdnBloc = BlocProvider.of<CDNBloc>(Global.appContext);
  static Map<String, Completer> _clientEventQueue = Map<String, Completer>();

  static init() {
    _eventChannel.receiveBroadcastStream().listen((res) {
      String event = res['event'].toString();
      LogUtil.v('====$event====', tag: TAG);
      LogUtil.v(res, tag: TAG);
      switch (event) {
        case 'send':
          String key = res['_id'];
          Uint8List pid = res['pid'];
          _clientEventQueue[key].complete(pid);
          break;
        case 'onMessage':
          try {
            Map<String, dynamic> content = jsonDecode(jsonDecode(res['data']['data'])['content'].toString().replaceAll('```', ''));
            onMessage(res['data']['src'], content);
          } catch (e) {
            LogUtil.v(e.toString(), tag: TAG);
          }
          break;
        case 'onConnect':
          Map node = res['node'];
          Map client = res['client'];
          break;
        default:
          break;
      }
    }, onError: (err) {
      LogUtil.e(err, tag: 'ClientEventChannel');
      if (_clientEventQueue[err.code] != null) {
        _clientEventQueue[err.code].completeError(err.message);
      }
    });
  }

  static onMessage(String src, content) async {
    LogUtil.v(content['Result']);
    LogUtil.v(content['Type']);
    LogUtil.v(src);
    var type = content['Type'];
    try {
      if (type != null && type.toString().contains('self_checker.sh')) {
        var cdn = await CdnMiner.getModelFromNshid(src);
        if (cdn != null) {
          cdn.data = content;
          await cdn.insertOrUpdate();
          _cdnBloc.add(LoadData(data: cdn));
        }
      }
    } catch (e) {
      LogUtil.v(e.toString(), tag: 'onMessage');
    }
  }

  static Future<bool> isConnected() async {
    try {
      LogUtil.v('isConnected   ', tag: TAG);
      return await _methodChannel.invokeMethod('isConnected');
    } catch (e) {
      throw e;
    }
  }

  static Future<void> createClient(String keystore, String password, {String identifier = 'nshell'}) async {
    try {
      LogUtil.v('createClient   ', tag: TAG);
      for (int i = 0; i < 3; i++) {
        try {
          await _methodChannel.invokeMethod('createClient', {
            'identifier': identifier,
            'keystore': keystore,
            'password': password,
          });
          break;
        } catch (e) {
          LogUtil.v(e);
        }
      }
    } catch (e) {
      throw e;
      LogUtil.v(e);
    }
  }

  static Future<void> disConnect() async {
    try {
      LogUtil.v('disConnect   ', tag: TAG);
      var status = await _methodChannel.invokeMethod('disConnect');
      if (status == 1) {
        LogUtil.v('disConnect  success ', tag: TAG);
      } else {
        LogUtil.v('disConnect  failed ', tag: TAG);
      }
    } catch (e) {
      throw e;
    }
  }

  static Future<Uint8List> sendText(List<String> dests, String data, {int maxHoldingSeconds = 0}) async {
    LogUtil.v('sendText  $data ', tag: TAG);
    Completer<Uint8List> completer = Completer<Uint8List>();
    String id = completer.hashCode.toString();
    _clientEventQueue[id] = completer;
    LogUtil.v(dests);
    try {
      await _methodChannel.invokeMethod('sendText', {
        '_id': id,
        'dests': dests,
        'data': data,
        'maxHoldingSeconds': maxHoldingSeconds,
      });
    } catch (e) {
      LogUtil.v('send fault');
      throw e;
    }
    return completer.future.whenComplete(() {
      _clientEventQueue.remove(id);
    });
  }
}
