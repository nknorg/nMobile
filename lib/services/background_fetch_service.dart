import 'dart:async';

import 'package:background_fetch/background_fetch.dart';
import 'package:common_utils/common_utils.dart';
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

class BackgroundFetchService {
  init() {
    final LocalAuthenticationService localAuth = locator<LocalAuthenticationService>();
    final LocalStorage _localStorage = LocalStorage();
    final SecureStorage _secureStorage = SecureStorage();
    ClientBloc _clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);
//    BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

    BackgroundFetch.configure(BackgroundFetchConfig(minimumFetchInterval: 15, stopOnTerminate: false, requiredNetworkType: NetworkType.ANY), (String taskId) async {
      LogUtil.v("[BackgroundFetch] Event received $taskId");
      // todo debug
      LocalNotification.debugNotification('[debug] background fetch begin', taskId);
      if (!localAuth.isProtectionEnabled) {
        BackgroundFetch.finish(taskId);
      } else {
        var isConnected = await NknClientPlugin.isConnected();
        if (!isConnected) {
          var wallet = await _localStorage.getItem(LocalStorage.NKN_WALLET_KEY, 0);
          var password = await _secureStorage.get('${SecureStorage.PASSWORDS_KEY}:${wallet['address']}');

          if (password != null) {
            _clientBloc.add(CreateClient(
              WalletSchema(address: wallet['address'], type: wallet['type'], name: wallet['name']),
              password,
            ));
          }
        }

        // IMPORTANT:  You must signal completion of your task or the OS can punish your app
        // for taking too long in the background.

        Timer(Duration(seconds: 20), () {
          // todo debug
          LocalNotification.debugNotification('[debug] background fetch end', taskId);
          BackgroundFetch.finish(taskId);
        });
      }
    }).then((int status) {

    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
    });
  }

  void backgroundFetchHeadlessTask(String taskId) async {
    LogUtil.v('[BackgroundFetch] Headless event received.');
    BackgroundFetch.finish(taskId);
  }
}
