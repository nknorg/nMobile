import 'package:get_it/get_it.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/wallet.dart';

import '../services/task_service.dart';
import 'application.dart';
import 'authentication.dart';
import 'chat/chat.dart';
import 'chat/receive_message.dart';
import 'notification.dart';

GetIt locator = GetIt.instance;

Application application;
Chat chat;
ReceiveMessage receiveMessage;
Authorization authorization;
Notification notification;
Contact contact;
Wallet wallet;

void setupLocator() {
  locator
    ..registerSingleton(Application())
    ..registerSingleton(Chat())
    ..registerSingleton(Authorization())
    ..registerSingleton(ReceiveMessage())
    ..registerSingleton(Notification())
    ..registerSingleton(Contact())
    ..registerSingleton(Wallet())
    ..registerSingleton(TaskService());
  application = locator.get<Application>();
  chat = locator.get<Chat>();
  receiveMessage = locator.get<ReceiveMessage>();
  authorization = locator.get<Authorization>();
  notification = locator.get<Notification>();
  contact = locator.get<Contact>();
  wallet = locator.get<Wallet>();
}
