import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/schemas/message.dart';

const _PLUGIN_PATH = "org.nkn.mobile.app/android_messaging_service";
const _CONFIG_CHANNEL_NAME = "$_PLUGIN_PATH/config";
const _MESSAGE_CHANNEL_NAME = "$_PLUGIN_PATH/messaging";
const _CONFIG_METHOD_NAME = "registerMessagingCallback";
const _REGISTERED_CALLBACK_ID = "callback_id";
const _ARGS_DATA = "data";

class AndroidMessagingService {
  static const MethodChannel _configChannel = MethodChannel(_CONFIG_CHANNEL_NAME);

  static Future<bool> registerOnMessage() async {
    Completer completer = new Completer<bool>();

    List<int> args = [
      PluginUtilities.getCallbackHandle(_messagingCallbackDispatcher).toRawHandle(),
      PluginUtilities.getCallbackHandle(_callback).toRawHandle(),
    ];

    _configChannel.invokeMethod(_CONFIG_METHOD_NAME, args).then((dynamic success) {
      completer.complete(true);
    }).catchError((error) {
      String message = error.toString();
      print('[AndroidMessagingService registerMessagingCallback] ‼️ $message');
      completer.complete(false);
    });
    return completer.future;
  }
}

ClientBloc _clientBloc = ClientBloc(chatBloc: ChatBloc(contactBloc: ContactBloc()));

void _callback(Map eventAndData) {
  print('[AndroidMessagingService _callback] $eventAndData');
  switch (eventAndData['event']) {
    case 'onMessage':
//      "data" to hashMapOf(
//          "src" to msgNkn.src,
//          "to" to accountPubkeyHex,
//          "data" to json,
//          "type" to msgNkn.type,
//          "encrypted" to msgNkn.encrypted,
//          "pid" to msgNkn.messageID
//      )
      if (!(_clientBloc.state is Connected)) {
        print('AndroidMessagingService | onMessage clientBloc.add(ConnectedClient)');
        _clientBloc.add(ConnectedClient());
        LocalNotification.init();
      }
      var data = eventAndData['data'];
      print('AndroidMessagingService | onMessage --> ClientBloc@${_clientBloc.hashCode.toString().substring(0, 3)}');
      _clientBloc.add(
        OnMessage(
          MessageSchema(from: data['src'], to: data['to'], data: data['data'], pid: data['pid']),
        ),
      );
      print('AndroidMessagingService | onMessage clientBloc.add | DONE.');
      break;
    default:
      break;
  }
}

void _messagingCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  const MethodChannel _messagingChannel = MethodChannel(_MESSAGE_CHANNEL_NAME);
  _messagingChannel.setMethodCallHandler((MethodCall call) async {
    final args = call.arguments;
    try {
      final Function callback = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(int.parse(args[_REGISTERED_CALLBACK_ID])),
      );
      if (callback == null) {
        print('[AndroidMessagingService _messagingCallbackDispatcher] ERROR! call.arguments: $args');
        return;
      }
      callback(args[_ARGS_DATA]);
    } catch (e, stacktrace) {
      print('[AndroidMessagingService _messagingCallbackDispatcher] ‼️ Callback error: ' + e.toString());
      print(stacktrace);
    }
  });
  // Signal to native side that the client dispatcher is ready to receive events.
  _messagingChannel.invokeMethod('initialized');
}
