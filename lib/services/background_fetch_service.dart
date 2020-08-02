import 'dart:async';
import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/log_tag.dart';

class BackgroundFetchService with Tag {
  init() {
    // ignore: close_sinks
    ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);
    // ignore: close_sinks
    WalletsBloc _walletBloc = BlocProvider.of<WalletsBloc>(Global.appContext);

    var config = BackgroundFetchConfig(
      minimumFetchInterval: 15,
      // __Android only__: but android use `AndroidMessagingService` instead.
      stopOnTerminate: true,
      // if the above `stopOnTerminate: false`, this should be true.
      enableHeadless: false,
      forceAlarmManager: false,
      // __Android only__: but android use `AndroidMessagingService` instead.
      startOnBoot: false,
      requiredNetworkType: NetworkType.ANY,
    );

    BackgroundFetch.configure(config, (String taskId) async {
      final _LOG = LOG(tag);
      final timeBegin = DateTime.now().millisecondsSinceEpoch;

      _LOG.d("[BackgroundFetch] Event received: $taskId");
      if (Platform.isAndroid) {
        _LOG.d("[BackgroundFetch] isAndroid: true, finish $taskId");
        BackgroundFetch.finish(taskId);
        return;
      }
      LocalNotification.debugNotification('[debug] background fetch begin', taskId);

      // May throw an exception! see: `DChatAuthenticationHelper.getPassword4BackgroundFetch()`.
      final localAuth = await LocalAuthenticationService.instance;
      if (!localAuth.isProtectionEnabled) {
        _LOG.d("[BackgroundFetch] isProtectionEnabled: false, finish $taskId");
        BackgroundFetch.finish(taskId);
      } else if (_clientBloc == null) {
        _LOG.e("[BackgroundFetch] _clientBloc == null", null);
        LocalNotification.debugNotification('[debug] _clientBloc == null', taskId);
        // In this case, the iOS native `MethodChannel` does not exist and cannot be recreated, it can only call finish.
        BackgroundFetch.finish(taskId);
      } else {
        // Can't exceed 30s.
        Timer(Duration(seconds: 25), () {
          final duration = ((DateTime.now().millisecondsSinceEpoch - timeBegin) / 1000.0).toStringAsFixed(3);
          _LOG.d("[BackgroundFetch] Timer finish: $taskId, timeDuration: ${duration}s");
          LocalNotification.debugNotification('[debug] background fetch end', '${duration}s');
          BackgroundFetch.finish(taskId);
//          if (Platform.isIOS) {
//            _clientBloc.add(DisConnected());
//          }
        });

        // Do work.
        var isConnected = _clientBloc.state is Connected;
        var isBackground = Global.state == null || Global.state == AppLifecycleState.paused || Global.state == AppLifecycleState.detached;
        _LOG.d("[BackgroundFetch] isConnected: $isConnected, isBackground: $isBackground.");
        if (!isConnected && isBackground) {
          _LOG.d("[BackgroundFetch] create connection...");
          LocalNotification.debugNotification('[debug] create connection...', '');
          _walletBloc.add(LoadWallets());
          DChatAuthenticationHelper.loadDChatUseWallet(_walletBloc, (wallet) {
            _LOG.d("[BackgroundFetch] create connection | onGetWallet...");
            LocalNotification.debugNotification('[debug] create connection', 'onGetWallet');
            DChatAuthenticationHelper.getPassword4BackgroundFetch(
              wallet: wallet,
              verifyProtectionEnabled: false,
              onGetPassword: (wallet, password) {
                _LOG.d("[BackgroundFetch] create connection | onGetPassword...");
                LocalNotification.debugNotification('[debug] create connection', 'onGetPassword');
                _clientBloc.add(CreateClient(wallet, password));
              },
            );
          });
        }
      }
    }).then((int status) {
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
      LOG(tag).e('[BackgroundFetch] configure ERROR.', e);
    });
  }
}

@Deprecated('__Android only__: but android use `AndroidMessagingService` instead.')
void backgroundFetchHeadlessTask(String taskId) async {
  print('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish(taskId);
}
