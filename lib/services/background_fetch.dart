import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class BackgroundFetchService with Tag {
  BackgroundFetchService();

  Future<void> install() async {
    int status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
        /// The minimum interval in minutes to execute background fetch events.
        minimumFetchInterval: 15,

        /// Set `true` to initiate background-fetch events when the device is rebooted. Defaults to `false`
        startOnBoot: false,

        /// Android only: Set false to continue background-fetch events after user terminates the app.
        stopOnTerminate: false,

        /// Android only When set true, ensure that this job will not run if the device is in active use.
        requiresDeviceIdle: true,

        /// Android only: Set true to enable the Headless mechanism,
        /// for handling fetch events after app termination.
        enableHeadless: true,

        /// Android only: Set true to force Task to use Android AlarmManager mechanism rather than JobScheduler.
        /// Will result in more precise scheduling of tasks at the cost of higher battery usage.
        forceAlarmManager: false,

        /// Android only Set detailed description of the kind of network your job requires.
        requiredNetworkType: NetworkType.ANY,

        /// Android only Specify that to run this job, the device's battery level must not be low.
        requiresBatteryNotLow: false,

        /// Android only Specify that to run this job, the device must be charging
        /// (or be a non-battery-powered device connected to permanent power, such as Android TV devices).
        requiresCharging: false,

        /// Android only Specify that to run this job, the device's available storage must not be low.
        requiresStorageNotLow: false,
      ),
      _onBackgroundFetch,
      (String taskId) async {
        logger.w("$TAG - init - timeout - taskId:$taskId");
        BackgroundFetch.finish(taskId);
      },
    );
    logger.i("$TAG - init - enable:${status != BackgroundFetch.STATUS_DENIED} - status:$status");
    if (Platform.isAndroid) {
      await BackgroundFetch.registerHeadlessTask(_backgroundFetchHeadlessTask);
    }
  }

  void _backgroundFetchHeadlessTask(HeadlessTask task) async {
    String taskId = task.taskId;
    bool isTimeout = task.timeout;
    if (isTimeout) {
      logger.w("$TAG - _backgroundFetchHeadlessTask - timeout - taskId:$taskId");
      BackgroundFetch.finish(taskId);
      return;
    }
    logger.d('$TAG - _backgroundFetchHeadlessTask - todo - taskId:$taskId');
    _onBackgroundFetch(taskId);
  }

  void _onBackgroundFetch(String taskId) async {
    if (clientCommon.status == ClientConnectStatus.connected) {
      logger.d("$TAG - _onBackgroundFetch - finish - taskId:$taskId");
      // TODO:GG test start
      await Future.delayed(Duration(seconds: 10));
      List<ContactSchema> contacts = await contactCommon.queryList(offset: 0, limit: 1);
      if (contacts.isEmpty) return;
      chatOutCommon.sendText(contacts[0].clientAddress, "正在后台:$taskId", contact: contacts[0]);
      // TODO:GG test end
      BackgroundFetch.finish(taskId);
      return;
    }
    logger.i("$TAG - _onBackgroundFetch - todo - taskId:$taskId");
    // signOut
    await clientCommon.signOut();
    await Future.delayed(Duration(seconds: 1));
    // signIn
    WalletSchema? wallet = await walletCommon.getDefault();
    await clientCommon.signIn(wallet);
    BackgroundFetch.finish(taskId);
    // TODO:GG test start
    await Future.delayed(Duration(seconds: 10));
    List<ContactSchema> contacts = await contactCommon.queryList(offset: 0, limit: 1);
    if (contacts.isEmpty) return;
    chatOutCommon.sendText(contacts[0].clientAddress, "正在后台:$taskId", contact: contacts[0]);
    // TODO:GG test end
  }
}
