import 'package:get_it/get_it.dart';
import 'package:nmobile/common/application.dart';
import 'package:nmobile/common/authentication.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/chat/chat_in.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/chat/session.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/contact/device_info.dart';
import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/common/private_group/prvaite_group.dart';
import 'package:nmobile/common/push/local_notification.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/common/topic/subscriber.dart';
import 'package:nmobile/common/topic/topic.dart';
import 'package:nmobile/common/wallet/wallet.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/helpers/ipfs.dart';
import 'package:nmobile/helpers/memory_cache.dart';
import 'package:nmobile/services/task.dart';

GetIt locator = GetIt.instance;

late Application application;
late TaskService taskService;
late Authorization authorization;
late LocalNotification localNotification;
// late BackgroundFetchService backgroundFetchService;
late AudioHelper audioHelper;
late IpfsHelper ipfsHelper;
late MemoryCache memoryCache;

late DB dbCommon;
late WalletCommon walletCommon;
late ClientCommon clientCommon;
late ChatCommon chatCommon;
late ChatInCommon chatInCommon;
late ChatOutCommon chatOutCommon;
late ContactCommon contactCommon;
late DeviceInfoCommon deviceInfoCommon;
late SessionCommon sessionCommon;
late TopicCommon topicCommon;
late SubscriberCommon subscriberCommon;
late PrivateGroupCommon privateGroupCommon;

void setupLocator() {
  // register
  locator.registerSingleton(Application());
  locator.registerSingleton(TaskService());
  locator.registerSingleton(Authorization());
  locator.registerSingleton(LocalNotification());
  // locator.registerSingleton(BackgroundFetchService());
  locator.registerSingleton(AudioHelper());
  locator.registerSingleton(IpfsHelper(Settings.debug));
  locator.registerSingleton(MemoryCache());

  locator.registerSingleton(DB());
  locator.registerSingleton(WalletCommon());
  locator.registerSingleton(ClientCommon());
  locator.registerSingleton(ChatCommon());
  locator.registerSingleton(ChatInCommon());
  locator.registerSingleton(ChatOutCommon());
  locator.registerSingleton(ContactCommon());
  locator.registerSingleton(DeviceInfoCommon());
  locator.registerSingleton(SessionCommon());
  locator.registerSingleton(TopicCommon());
  locator.registerSingleton(SubscriberCommon());
  locator.registerSingleton(PrivateGroupCommon());

  // instance
  application = locator.get<Application>();
  taskService = locator.get<TaskService>();
  authorization = locator.get<Authorization>();
  localNotification = locator.get<LocalNotification>();
  // backgroundFetchService = locator.get<BackgroundFetchService>();
  audioHelper = locator.get<AudioHelper>();
  ipfsHelper = locator.get<IpfsHelper>();
  memoryCache = locator.get<MemoryCache>();

  dbCommon = locator.get<DB>();
  walletCommon = locator.get<WalletCommon>();
  clientCommon = locator.get<ClientCommon>();
  chatCommon = locator.get<ChatCommon>();
  chatInCommon = locator.get<ChatInCommon>();
  chatOutCommon = locator.get<ChatOutCommon>();
  contactCommon = locator.get<ContactCommon>();
  deviceInfoCommon = locator.get<DeviceInfoCommon>();
  sessionCommon = locator.get<SessionCommon>();
  topicCommon = locator.get<TopicCommon>();
  subscriberCommon = locator.get<SubscriberCommon>();
  privateGroupCommon = locator.get<PrivateGroupCommon>();
}
