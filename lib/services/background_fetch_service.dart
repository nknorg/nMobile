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
import 'package:nmobile/utils/nlog_util.dart';

class BackgroundFetchService {
  init() {
    /*BackgroundFetch.scheduleTask(TaskConfig(
        taskId: 'com.foo.customtask',
        delay: 1 * 60 * 1000, // milliseconds
        forceAlarmManager: true,
        periodic: false));*/

    BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          requiredNetworkType: NetworkType.ANY,
          enableHeadless: true,
          forceAlarmManager: true,
          startOnBoot: true,
        ), (String taskId) async {
      NLog.e("[BackgroundFetch] ----->>> for iOS | Event received $taskId");
      _ensureBackgroundFetchFinished(taskId, await _doBackgroundFetchWork(taskId));
    }).then((int status) {
      switch (status) {
        case BackgroundFetch.STATUS_RESTRICTED:
          NLog.v("[BackgroundFetch] finish status: STATUS_RESTRICTED");
          break;
        case BackgroundFetch.STATUS_DENIED:
          NLog.v("[BackgroundFetch] finish status: STATUS_DENIED");
          break;
        case BackgroundFetch.STATUS_AVAILABLE:
          NLog.v("[BackgroundFetch] finish status: STATUS_AVAILABLE");
          break;
        default:
          NLog.d("[BackgroundFetch] finish status: $status");
      }
    }).catchError((e) {
      NLog.e('[BackgroundFetch] configure ERROR: $e');
    });
  }
}

void backgroundFetchHeadlessTask(String taskId) async {
  // Since the call back is in a newly created 'Flutter Engine(Dart VM)' environment, 'Global' is always uninitialized.
  print('[BackgroundFetch] ----->>> for Android | Headless event received: $taskId');
  print('[BackgroundFetch] <<<----- Done as deprecated.');
  // @Deprecated
  //_ensureBackgroundFetchFinished(taskId, await _doBackgroundFetchWork(taskId));
}

Future<ClientBloc> _doBackgroundFetchWork(String taskId) async {
  try {
    // for debug
    LocalNotification.debugNotification('[debug] background fetch begin', taskId);

    switch (taskId) {
      case "com.foo.customtask":
        NLog.d("[BackgroundFetch] test custom task: com.foo.customtask");
        break;
      default:
        final LocalAuthenticationService localAuth = LocalAuthenticationService.instance;
        final LocalStorage localStorage = LocalStorage();
        final SecureStorage secureStorage = SecureStorage();

        if (localAuth.isProtectionEnabled) {
          var isConnected = await NknClientPlugin.isConnected();
          if (!isConnected && Global.currentChatId != null) {
            NLog.d("[BackgroundFetch] no connect");
            var wallet = await localStorage.getItem(LocalStorage.NKN_WALLET_KEY, 0);
            if (wallet != null) {
              var password = await secureStorage.get('${SecureStorage.PASSWORDS_KEY}:${wallet['address']}');
              if (password != null) {
                // Can't work for Android `backgroundFetchHeadlessTask`. but it DOESN'T MATTER.
                final ClientBloc clientBloc = BlocProvider.of<ClientBloc>(Global.appContext);
//                final ClientBloc clientBloc = ClientBloc(chatBloc: ChatBloc(contactBloc: ContactBloc()));
                NLog.v('[BackgroundFetch] scheduled: $taskId, ClientBloc@${clientBloc.hashCode.toString().substring(0, 3)}');

                clientBloc.add(CreateClient(
                  WalletSchema(address: wallet['address'], type: wallet['type'], name: wallet['name']),
                  password,
                ));
                // Do NOT close `clientBloc`.
                return null; // clientBloc;
              }
            }
          } else {
            NLog.v("[BackgroundFetch] connecting...");
          }
        }
    }
    return null;
  } catch (e) {
    NLog.e('[BackgroundFetch] error: $e');
    return null;
  }
}

_ensureBackgroundFetchFinished(String taskId, ClientBloc clientBloc) {
  // IMPORTANT:  You must signal completion of your task or the OS can punish your app
  // for taking too long in the background.
  Timer(Duration(seconds: 20), () {
    clientBloc?.close();
    // for debug
    LocalNotification.debugNotification('[debug] background fetch end', taskId);
    BackgroundFetch.finish(taskId);
    NLog.e('[BackgroundFetch] FINISHED <<<----------------------------------');
  });
}
