import 'package:get_it/get_it.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/device/device_info.dart';
import 'package:nmobile/common/push/local_notification.dart';
import 'package:nmobile/common/session/session.dart';
import 'package:nmobile/common/wallet/wallet.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/helpers/memory_cache.dart';

import '../services/task.dart';
import 'application.dart';
import 'authentication.dart';
import 'chat/chat.dart';
import 'chat/chat_in.dart';

GetIt locator = GetIt.instance;

late Application application;
late TaskService taskService;
late Authorization authorization;
late LocalNotification localNotification;
// late BackgroundFetchService backgroundFetchService;
late AudioHelper audioHelper;
late MemoryCache memoryCache;

late WalletCommon walletCommon;
late ClientCommon clientCommon;
late ContactCommon contactCommon;
late SessionCommon sessionCommon;
late ChatCommon chatCommon;
late ChatInCommon chatInCommon;
late ChatOutCommon chatOutCommon;
late DeviceInfoCommon deviceInfoCommon;

void setupLocator() {
  // register
  locator.registerSingleton(Application());
  locator.registerSingleton(TaskService());
  locator.registerSingleton(Authorization());
  locator.registerSingleton(LocalNotification());
  // locator.registerSingleton(BackgroundFetchService());
  locator.registerSingleton(AudioHelper());
  locator.registerSingleton(MemoryCache());

  locator.registerSingleton(WalletCommon());
  locator.registerSingleton(ClientCommon());
  locator.registerSingleton(ContactCommon());
  locator.registerSingleton(SessionCommon());
  locator.registerSingleton(ChatCommon());
  locator.registerSingleton(ChatInCommon());
  locator.registerSingleton(ChatOutCommon());
  locator.registerSingleton(DeviceInfoCommon());

  // instance
  application = locator.get<Application>();
  taskService = locator.get<TaskService>();
  authorization = locator.get<Authorization>();
  localNotification = locator.get<LocalNotification>();
  // backgroundFetchService = locator.get<BackgroundFetchService>();
  audioHelper = locator.get<AudioHelper>();
  memoryCache = locator.get<MemoryCache>();

  walletCommon = locator.get<WalletCommon>();
  clientCommon = locator.get<ClientCommon>();
  contactCommon = locator.get<ContactCommon>();
  sessionCommon = locator.get<SessionCommon>();
  chatCommon = locator.get<ChatCommon>();
  chatInCommon = locator.get<ChatInCommon>();
  chatOutCommon = locator.get<ChatOutCommon>();
  deviceInfoCommon = locator.get<DeviceInfoCommon>();
}
