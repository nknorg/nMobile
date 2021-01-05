import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/model/db/contact_repo.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/utils/log_tag.dart';

const _PLUGIN_PATH = "org.nkn.mobile.app/android_messaging_service";
const _CONFIG_CHANNEL_NAME = "$_PLUGIN_PATH/config";
const _INIT_CHANNEL_NAME = "$_PLUGIN_PATH/initialize";
const _CONFIG_METHOD_NAME = "registerMessagingCallback";
const _REGISTERED_CALLBACK_ID = "callback_id";
const _EVENT_AND_DATA = "event_and_data";
const _INITIALIZED = "initialized";
const LOG _LOG = LOG('AndroidMessagingService');

class AndroidMessagingService {
  static const MethodChannel _configChannel = MethodChannel(_CONFIG_CHANNEL_NAME);

  static Future<bool> registerNativeCallback() async {
    Completer completer = new Completer<bool>();

    List<int> args = [
      PluginUtilities.getCallbackHandle(_callbackDispatcher).toRawHandle(),
      PluginUtilities.getCallbackHandle(_realCallback).toRawHandle(),
    ];

    _configChannel.invokeMethod(_CONFIG_METHOD_NAME, args).then((dynamic success) {
      completer.complete(true);
    }).catchError((error) {
      _LOG.e('registerNativeCallback ‼️', error);
      completer.complete(false);
    });
    return completer.future;
  }
}

NKNClientBloc _clientBloc;

Future<void> _onNativeReady() async {
  _LOG.i('_onNativeReady');

  ChatBloc chatBloc = ChatBloc(contactBloc: ContactBloc());
  _clientBloc ??= NKNClientBloc(cBloc: chatBloc);

  await Global.initData();
  final walletBloc = WalletsBloc();
  walletBloc.add(LoadWallets());

  WalletSchema wallet = await DChatAuthenticationHelper.loadUserDefaultWallet();
  DChatAuthenticationHelper.getPassword4BackgroundFetch(
    wallet: wallet,
    verifyProtectionEnabled: false,
    onGetPassword: (wallet, password) {
      Global.debugLog('android_messaging_service.dart onGetPassword');
      _clientBloc.add(NKNCreateClientEvent(wallet, password));
    },
  );
}

void _realCallback(Map eventAndData) async {
  final event = eventAndData['event'];
  _LOG.i('_realCallback | event:$event');
  switch (event) {
    case 'onNativeReady':
      await _onNativeReady();
      break;
    case 'destroy':
      NKNClientCaller.disConnect();
      NKNDataManager().close();
      _clientBloc.close();
      break;
    default:
      _LOG.w('_realCallback | unhandled event:$event');
      break;
  }
}

void _callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  const MethodChannel initChannel = MethodChannel(_INIT_CHANNEL_NAME);
  initChannel.setMethodCallHandler((MethodCall call) async {
    final args = call.arguments;
    try {
      final Function callback = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(int.parse(args[_REGISTERED_CALLBACK_ID])),
      );
      if (callback == null) {
        _LOG.w('_callbackDispatcher ‼️ ERROR! call.arguments: $args');
        return;
      }
      await callback(args[_EVENT_AND_DATA]);
    } catch (e, stacktrace) {
      _LOG.e('_callbackDispatcher ‼️', e);
      print(stacktrace);
    }
  });
  // Signal to native side that the client dispatcher is ready to receive events.
  initChannel.invokeMethod(_INITIALIZED);
}
