import 'dart:async';
import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/log_tag.dart';

import 'package:nmobile/blocs/account_depends_bloc.dart';

const String fetch_background_taskId = "com.transistorsoft.nmobile.backgroundtask";

class BackgroundFetchService with Tag,AccountDependsBloc{
  init() {
    if (Platform.isIOS){
      BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        forceAlarmManager: false,
        stopOnTerminate: true,
        startOnBoot: false,
        enableHeadless: false,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.ANY,
      ), _onBackgroundFetch).then((int status) {
        print('[BackgroundFetch] configure success: $status');
        switch (status) {
          case BackgroundFetch.STATUS_RESTRICTED:
            LOG(tag).w('[BackgroundFetch] STATUS_RESTRICTED.');
            break;
          case BackgroundFetch.STATUS_AVAILABLE:
            LOG(tag).i('[BackgroundFetch] STATUS_AVAILABLE.');
            break;
          case BackgroundFetch.STATUS_DENIED:
            LOG(tag).e('[BackgroundFetch] STATUS_DENIED.', null);
            break;
        }
      }).catchError((e) {
        print('[BackgroundFetch] configure ERROR: $e');
      });
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
        print('[BackgroundFetch] configure success: $status');
        switch (status) {
          case BackgroundFetch.STATUS_RESTRICTED:
            LOG(tag).w('[BackgroundFetch] STATUS_RESTRICTED.');
            break;
          case BackgroundFetch.STATUS_AVAILABLE:
            LOG(tag).i('[BackgroundFetch] STATUS_AVAILABLE.');
            break;
          case BackgroundFetch.STATUS_DENIED:
            LOG(tag).e('[BackgroundFetch] STATUS_DENIED.', null);
            break;
        }
      }).catchError((e) {
        print('[BackgroundFetch] configure ERROR: $e');
      });
    }
  }

  void _onBackgroundFetch(String taskId) async {
    // ignore: close_sinks
    ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);
    // ignore: close_sinks
    WalletsBloc _walletBloc = BlocProvider.of<WalletsBloc>(Global.appContext);

    DateTime timestamp = new DateTime.now();
    // This is the fetch-event callback.
    print("[BackgroundFetch] Event receivedXXXX: $taskId");

    final timeBegin = DateTime.now().millisecondsSinceEpoch;

    if (Platform.isAndroid) {
      BackgroundFetch.finish(taskId);
      return;
    }
    // May throw an exception! see: `DChatAuthenticationHelper.getPassword4BackgroundFetch()`.
    final localAuth = await LocalAuthenticationService.instance;
    if (!localAuth.isProtectionEnabled) {
      BackgroundFetch.finish(taskId);
      print("[nknbgfetch] on isProtectionEnabled");
    }
    else if (_clientBloc == null) {
      // In this case, the iOS native `MethodChannel` does not exist and cannot be recreated, it can only call finish.
      BackgroundFetch.finish(taskId);
      print("[nknbgfetch] on _clientBloc==null");
    }
    else {
      Future.delayed(Duration(seconds: 15), (){
        account.client.backOff();
        BackgroundFetch.finish(taskId);
      });

      // Do work.
      var isConnected = _clientBloc.state is Connected;
      bool inBg = await Global.isInBackground;
      print("[nknbgfetch] on isConnected"+isConnected.toString());
      if (inBg) {
        _walletBloc.add(LoadWallets());
        DChatAuthenticationHelper.loadDChatUseWallet(_walletBloc, (wallet) {
          print("[nknbgfetch] on loadDChatUseWallet");
          DChatAuthenticationHelper.getPassword4BackgroundFetch(
            wallet: wallet,
            verifyProtectionEnabled: false,
            onGetPassword: (wallet, password) {
              print("[nknbgfetch] on on CreateClient");
              account.client.backOn();
              _clientBloc.add(CreateClient(wallet, password));
              _clientBloc.add(ConnectedClient());
            },
          );
        });
      }
      else {
        // do something
        int sum = 0;
        for (int i = 0; i < 5; i++){
          sum += i;
        }
        print("in no bg Do the math keep alive__"+sum.toString());
      }
    }
  }
}

@Deprecated('__Android only__: but android use `AndroidMessagingService` instead.')
void backgroundFetchHeadlessTask(String taskId) async {
  print('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish(taskId);
}

