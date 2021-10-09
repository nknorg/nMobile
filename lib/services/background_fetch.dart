import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';

@deprecated
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
        requiresDeviceIdle: false,

        /// Android only: Set true to enable the Headless mechanism,
        /// for handling fetch events after app termination.
        enableHeadless: true,

        /// Android only: Set true to force Task to use Android AlarmManager mechanism rather than JobScheduler.
        /// Will result in more precise scheduling of tasks at the cost of higher battery usage.
        forceAlarmManager: true,

        /// Android only Set detailed description of the kind of network your job requires.
        requiredNetworkType: NetworkType.NONE,

        /// Android only Specify that to run this job, the device's battery level must not be low.
        requiresBatteryNotLow: false,

        /// Android only Specify that to run this job, the device must be charging
        /// (or be a non-battery-powered device connected to permanent power, such as Android TV devices).
        requiresCharging: false,

        /// Android only Specify that to run this job, the device's available storage must not be low.
        requiresStorageNotLow: false,
      ),
      _onBackgroundFetch,
      _onBackgroundTimeout,
    );
    if (status == BackgroundFetch.STATUS_DENIED) {
      logger.w("$TAG - init - enable:false - status:$status");
    } else {
      logger.i("$TAG - init - enable:true - status:$status");
    }
    await BackgroundFetch.registerHeadlessTask(_backgroundFetchHeadlessTask);
  }

  void _backgroundFetchHeadlessTask(HeadlessTask task) async {
    String taskId = task.taskId;
    bool isTimeout = task.timeout;
    if (isTimeout) {
      logger.w("$TAG - _backgroundFetchHeadlessTask - timeout - taskId:$taskId");
      BackgroundFetch.finish(taskId);
      return;
    }
    logger.i('$TAG - _backgroundFetchHeadlessTask - run - taskId:$taskId');
    _onBackgroundFetch(taskId);
  }

  void _onBackgroundFetch(String taskId) async {
    if (application.appLifecycleState == AppLifecycleState.resumed) {
      logger.i("$TAG - _onBackgroundFetch - finish - on resumed - taskId:$taskId");
      BackgroundFetch.finish(taskId);
      return;
    }
    if (!clientCommon.isClientCreated) {
      logger.i("$TAG - _onBackgroundFetch - finish - client closed - taskId:$taskId");
      BackgroundFetch.finish(taskId);
      return;
    }
    // signOut
    logger.i("$TAG - _onBackgroundFetch - run start - taskId:$taskId");
    try {
      await clientCommon.signOut(clearWallet: false, closeDB: true);
      logger.i("$TAG - _onBackgroundFetch - run success - taskId:$taskId");
    } catch (e) {
      logger.w("$TAG - _onBackgroundFetch - run fail - taskId:$taskId");
      handleError(e);
    }
    // finish
    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundTimeout(String taskId) async {
    logger.w("$TAG - init - timeout - taskId:$taskId");
    BackgroundFetch.finish(taskId);
  }
}
