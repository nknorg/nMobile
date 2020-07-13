import 'dart:async';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/nlog_util.dart';

class BackgroundFetchService {
  bool isFirstStart = true; // init start

  init() {
    final LocalStorage _localStorage = LocalStorage();
    final SecureStorage _secureStorage = SecureStorage();
    ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);

    var config = BackgroundFetchConfig(
      minimumFetchInterval: 15,
      stopOnTerminate: false,
      enableHeadless: false,
      forceAlarmManager: false,
      startOnBoot: true,
      requiredNetworkType: NetworkType.ANY,
    );

    BackgroundFetch.configure(config, (String taskId) async {
      print("[BackgroundFetch] Event received $taskId");
      // todo debug
      LocalNotification.debugNotification('[debug] background fetch begin', taskId);

      final localAuth = await LocalAuthenticationService.instance;
      if (!localAuth.isProtectionEnabled) {
        print("[BackgroundFetch] isProtectionEnabled: false, finish $taskId");
        BackgroundFetch.finish(taskId);
      } else {
        var isConnected = _clientBloc.state is Connected; // await NknClientPlugin.isConnected();
        if (!isConnected && !isFirstStart) {
          print("[BackgroundFetch] no Connect");
          var wallet = await _localStorage.getItem(LocalStorage.NKN_WALLET_KEY, 0);
          if (wallet != null) {
            var password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:${wallet['address']}');

            if (password != null) {
              _clientBloc.add(CreateClient(
                WalletSchema(address: wallet['address'], type: wallet['type'], name: wallet['name']),
                password,
              ));
            }
          }
        } else {
          isFirstStart = false;
          print("[BackgroundFetch] Connecting");
        }

        Timer(Duration(seconds: 20), () {
          // todo debug
          LocalNotification.debugNotification('[debug] background fetch end', taskId);

          print("[BackgroundFetch] Timer finish $taskId");
          BackgroundFetch.finish(taskId);
//          if (Platform.isIOS) {
//            NknClientPlugin.disConnect();
//          }
        });
      }
    }).then((int status) {}).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
    });
  }
}

@deprecated
void backgroundFetchHeadlessTask(String taskId) async {
  NLog.d('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish(taskId);
}
