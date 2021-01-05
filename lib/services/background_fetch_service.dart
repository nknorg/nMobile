import 'dart:async';
import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/utils/log_tag.dart';


const String fetch_background_taskId = "com.transistorsoft.nmobile.backgroundtask";

class BackgroundFetchService with Tag{
  init() {
    if (Platform.isIOS){
      // BackgroundFetch.configure(BackgroundFetchConfig(
      //   minimumFetchInterval: 15,
      //   forceAlarmManager: false,
      //   stopOnTerminate: true,
      //   startOnBoot: false,
      //   enableHeadless: false,
      //   requiresBatteryNotLow: false,
      //   requiresCharging: false,
      //   requiresStorageNotLow: false,
      //   requiresDeviceIdle: false,
      //   requiredNetworkType: NetworkType.ANY,
      // ), _onBackgroundFetch).then((int status) {
      //   print('[BackgroundFetch] configure success: $status');
      //   switch (status) {
      //     case BackgroundFetch.STATUS_RESTRICTED:
      //       LOG(tag).w('[BackgroundFetch] STATUS_RESTRICTED.');
      //       break;
      //     case BackgroundFetch.STATUS_AVAILABLE:
      //       LOG(tag).i('[BackgroundFetch] STATUS_AVAILABLE.');
      //       break;
      //     case BackgroundFetch.STATUS_DENIED:
      //       LOG(tag).e('[BackgroundFetch] STATUS_DENIED.', null);
      //       break;
      //   }
      // }).catchError((e) {
      //   print('[BackgroundFetch] configure ERROR: $e');
      // });
    }
    else{
      BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        forceAlarmManager: false,
        stopOnTerminate: true,
        startOnBoot: false,
        enableHeadless: false,
        requiredNetworkType: NetworkType.ANY,
      ), _onBackgroundFetch).then((int status) {
        Global.debugLog('[BackgroundFetch] configure success: $status');
        switch (status) {
          case BackgroundFetch.STATUS_RESTRICTED:
            break;
          case BackgroundFetch.STATUS_AVAILABLE:
            Global.debugLog('[BackgroundFetch] STATUS_AVAILABLE.');
            break;
          case BackgroundFetch.STATUS_DENIED:
            Global.debugLog('[BackgroundFetch] STATUS_DENIED.');
            break;
        }
      }).catchError((e) {
        print('[BackgroundFetch] configure ERROR: $e');
      });
    }
  }

  void _onBackgroundFetch(String taskId) async {
    // ignore: close_sinks
    NKNClientBloc _clientBloc = BlocProvider.of<NKNClientBloc>(Global.appContext);
    // ignore: close_sinks
    WalletsBloc _walletBloc = BlocProvider.of<WalletsBloc>(Global.appContext);

    DateTime timestamp = new DateTime.now();
    // This is the fetch-event callback.

    final timeBegin = DateTime.now().millisecondsSinceEpoch;

    if (Platform.isAndroid) {
      BackgroundFetch.finish(taskId);
      return;
    }

    if (_clientBloc == null) {
      // In this case, the iOS native `MethodChannel` does not exist and cannot be recreated, it can only call finish.
      BackgroundFetch.finish(taskId);
      print("[nknbgfetch] on _clientBloc==null");
    }
    else {
      Future.delayed(Duration(seconds: 15), (){
        // NKNClientCaller.o();
        BackgroundFetch.finish(taskId);
      });

      WalletSchema wallet = await DChatAuthenticationHelper.loadUserDefaultWallet();
      print("[nknbgfetch] on loadDChatUseWallet");
      DChatAuthenticationHelper.getPassword4BackgroundFetch(
        wallet: wallet,
        verifyProtectionEnabled: false,
        onGetPassword: (wallet, password) {
          Global.debugLog('background_fetch_service.dart NKNCreateClientEvent');
          _clientBloc.add(NKNCreateClientEvent(wallet, password));
        },
      );
    }
  }
}

@Deprecated('__Android only__: but android use `AndroidMessagingService` instead.')
void backgroundFetchHeadlessTask(String taskId) async {
  print('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish(taskId);
}

