import 'package:get_it/get_it.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/wallet/wallet.dart';

import 'authentication.dart';
import '../services/task_service.dart';
import 'application.dart';
import 'chat/chat.dart';
import 'chat/receive_message.dart';
import 'notification.dart';

GetIt locator = GetIt.instance;

Application application;
TaskService taskService;
Notification notification;
Authorization authorization;

Chat chat;
ReceiveMessage receiveMessage;
Contact contact;
Wallet wallet;

void setupLocator() {
  locator
    ..registerSingleton(Application())
    ..registerSingleton(TaskService())
    ..registerSingleton(Notification())
    ..registerSingleton(Authorization())
    ..registerSingleton(Chat())
    ..registerSingleton(ReceiveMessage())
    ..registerSingleton(Contact())
    ..registerSingleton(Wallet());

  application = locator.get<Application>();
  taskService = locator.get<TaskService>();
  notification = locator.get<Notification>();
  authorization = locator.get<Authorization>();

  chat = locator.get<Chat>();
  receiveMessage = locator.get<ReceiveMessage>();
  contact = locator.get<Contact>();
  wallet = locator.get<Wallet>();
}
