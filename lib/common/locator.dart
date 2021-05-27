import 'package:get_it/get_it.dart';
import 'package:nmobile/common/chat/send_message.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/wallet/wallet.dart';

import '../services/task_service.dart';
import 'application.dart';
import 'authentication.dart';
import 'chat/chat.dart';
import 'chat/receive_message.dart';
import 'notification.dart';

GetIt locator = GetIt.instance;

late Application application;
late TaskService taskService;
late Notification notification;
late Authorization authorization;

late ChatCommon chatCommon;
late ReceiveMessage receiveMessage;
late SendMessage sendMessage;
late ContactCommon contactCommon;
late WalletCommon walletCommon;

void setupLocator() {
  locator..registerSingleton(Application())..registerSingleton(TaskService())..registerSingleton(Notification())..registerSingleton(Authorization())..registerSingleton(ChatCommon())..registerSingleton(ReceiveMessage())..registerSingleton(SendMessage())..registerSingleton(ContactCommon())..registerSingleton(WalletCommon());

  application = locator.get<Application>();
  taskService = locator.get<TaskService>();
  notification = locator.get<Notification>();
  authorization = locator.get<Authorization>();

  chatCommon = locator.get<ChatCommon>();
  receiveMessage = locator.get<ReceiveMessage>();
  sendMessage = locator.get<SendMessage>();
  contactCommon = locator.get<ContactCommon>();
  walletCommon = locator.get<WalletCommon>();
}
