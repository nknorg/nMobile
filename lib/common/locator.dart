import 'package:get_it/get_it.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/contact/contact.dart';
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
late AudioHelper audioHelper;
late LocalNotification localNotification;
// late BackgroundFetchService backgroundFetchService;
late MemoryCache memoryCache;

late ClientCommon clientCommon;
late ChatCommon chatCommon;
late SessionCommon sessionCommon;
late ChatInCommon chatInCommon;
late ChatOutCommon chatOutCommon;
late ContactCommon contactCommon;
late WalletCommon walletCommon;

void setupLocator() {
  // register
  locator.registerSingleton(Application());
  locator.registerSingleton(TaskService());
  locator.registerSingleton(Authorization());
  locator.registerSingleton(AudioHelper());
  locator.registerSingleton(LocalNotification());
  // locator.registerSingleton(BackgroundFetchService());
  locator.registerSingleton(MemoryCache());

  locator.registerSingleton(ClientCommon());
  locator.registerSingleton(ChatCommon());
  locator.registerSingleton(SessionCommon());
  locator.registerSingleton(ChatInCommon());
  locator.registerSingleton(ChatOutCommon());
  locator.registerSingleton(ContactCommon());
  locator.registerSingleton(WalletCommon());

  // instance
  application = locator.get<Application>();
  taskService = locator.get<TaskService>();
  authorization = locator.get<Authorization>();
  audioHelper = locator.get<AudioHelper>();
  localNotification = locator.get<LocalNotification>();
  // backgroundFetchService = locator.get<BackgroundFetchService>();
  memoryCache = locator.get<MemoryCache>();

  clientCommon = locator.get<ClientCommon>();
  chatCommon = locator.get<ChatCommon>();
  sessionCommon = locator.get<SessionCommon>();
  chatInCommon = locator.get<ChatInCommon>();
  chatOutCommon = locator.get<ChatOutCommon>();
  contactCommon = locator.get<ContactCommon>();
  walletCommon = locator.get<WalletCommon>();
}
