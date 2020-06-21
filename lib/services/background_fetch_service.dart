import 'dart:async';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/utils/nlog_util.dart';

class BackgroundFetchService {
  init() {
    final LocalAuthenticationService localAuth = locator<LocalAuthenticationService>();
    final LocalStorage _localStorage = LocalStorage();
    final SecureStorage _secureStorage = SecureStorage();
    ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);

    var config = BackgroundFetchConfig(
      minimumFetchInterval: 15,
      stopOnTerminate: false,
      enableHeadless: true,
      forceAlarmManager: false,
      requiredNetworkType: NetworkType.ANY,
    );

    BackgroundFetch.configure(config, (String taskId) async {
      NLog.d("[BackgroundFetch] Event received $taskId");
      // todo debug
      LocalNotification.debugNotification('[debug] background fetch begin', taskId);
      if (!localAuth.isProtectionEnabled) {
        BackgroundFetch.finish(taskId);
      } else {
        var isConnected = await NknClientPlugin.isConnected();
        if (!isConnected && Global.currentChatId != null) {
          NLog.d("[BackgroundFetch] no Connect");
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
          NLog.d("[BackgroundFetch] Connectting");
        }

        Timer(Duration(seconds: 20), () {
          // todo debug
          LocalNotification.debugNotification('[debug] background fetch end', taskId);
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

void backgroundFetchHeadlessTask(String taskId) async {
  NLog.d('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish(taskId);
}
