import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class BackgroundFetchService {
  void backgroundFetchHeadlessTask(HeadlessTask task) async {
    String taskId = task.taskId;
    bool isTimeout = task.timeout;
    if (isTimeout) {
      logger.i("[BackgroundFetch] Headless task timed-out: $taskId");
      BackgroundFetch.finish(taskId);
      return;
    }
    print('[BackgroundFetch] Headless event received.');
    _onBackgroundFetch(taskId);
  }

  Future<void> install() async {
    if (Platform.isAndroid) {
      BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
    }
    int status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
        /// Android only: Set true to force Task to use Android AlarmManager mechanism rather than JobScheduler.
        /// Will result in more precise scheduling of tasks at the cost of higher battery usage.
        forceAlarmManager: false,

        /// Android only: Set false to continue background-fetch events after user terminates the app.
        stopOnTerminate: false,

        /// Android only: Set true to enable the Headless mechanism,
        /// for handling fetch events after app termination.
        enableHeadless: true,

        /// Android only Specify that to run this job, the device's battery level must not be low.
        requiresBatteryNotLow: false,

        /// Android only Specify that to run this job, the device must be charging
        /// (or be a non-battery-powered device connected to permanent power, such as Android TV devices).
        requiresCharging: false,

        /// Android only Specify that to run this job, the device's available storage must not be low.
        requiresStorageNotLow: false,

        /// Android only When set true, ensure that this job will not run if the device is in active use.
        requiresDeviceIdle: true,

        /// Android only Set detailed description of the kind of network your job requires.
        requiredNetworkType: NetworkType.ANY,

        /// The minimum interval in minutes to execute background fetch events.
        minimumFetchInterval: 15,
      ),
      _onBackgroundFetch,
      (String taskId) async {
        print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
        BackgroundFetch.finish(taskId);
      },
    );

    print('[BackgroundFetch] configure success: $status');
  }

  void _onBackgroundFetch(String taskId) async {
    print("[BackgroundFetch] Event received $taskId");
    if (chatCommon.status == ChatConnectStatus.connected) {
      BackgroundFetch.finish(taskId);
      return;
    }
    Future.delayed(Duration(seconds: 20), () {
      chatCommon.close();
      BackgroundFetch.finish(taskId);
    });
    WalletSchema? wallet = await walletCommon.getDefault();
    chatCommon.signIn(wallet);
  }
}
