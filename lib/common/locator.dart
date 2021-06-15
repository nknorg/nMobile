import 'package:get_it/get_it.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/session/session.dart';
import 'package:nmobile/common/wallet/wallet.dart';
import 'package:nmobile/helpers/memory_cache.dart';
import 'package:nmobile/services/background_fetch.dart';

import '../services/task.dart';
import 'application.dart';
import 'authentication.dart';
import 'chat/chat.dart';
import 'chat/chat_in.dart';
import 'notification.dart';

GetIt locator = GetIt.instance;

late Application application;
late TaskService taskService;
late BackgroundFetchService backgroundFetchService;
late Notification notification;
late Authorization authorization;

late ClientCommon clientCommon;
late ChatCommon chatCommon;
late SessionCommon sessionCommon;
late ChatInCommon chatInCommon;
late ChatOutCommon chatOutCommon;
late ContactCommon contactCommon;
late WalletCommon walletCommon;
late MemoryCache memoryCache;

void setupLocator() {
  locator..registerSingleton(Application())..registerSingleton(TaskService())..registerSingleton(BackgroundFetchService())..registerSingleton(Notification())..registerSingleton(Authorization())..registerSingleton(ClientCommon())..registerSingleton(ChatCommon())..registerSingleton(SessionCommon())..registerSingleton(ChatInCommon())..registerSingleton(ChatOutCommon())..registerSingleton(ContactCommon())..registerSingleton(WalletCommon())..registerSingleton(MemoryCache());

  application = locator.get<Application>();
  taskService = locator.get<TaskService>();
  backgroundFetchService = locator.get<BackgroundFetchService>();
  notification = locator.get<Notification>();
  authorization = locator.get<Authorization>();

  clientCommon = locator.get<ClientCommon>();
  chatCommon = locator.get<ChatCommon>();
  sessionCommon = locator.get<SessionCommon>();
  chatInCommon = locator.get<ChatInCommon>();
  chatOutCommon = locator.get<ChatOutCommon>();
  contactCommon = locator.get<ContactCommon>();
  walletCommon = locator.get<WalletCommon>();

  memoryCache = locator.get<MemoryCache>();
}
