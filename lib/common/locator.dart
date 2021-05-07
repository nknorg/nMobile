import 'package:get_it/get_it.dart';
import '../services/task_service.dart';

import 'application.dart';
import 'authentication.dart';
import 'chat/chat.dart';
import 'chat/receive_message.dart';

GetIt locator = GetIt.instance;

Application application;
Chat chat;
ReceiveMessage receiveMessage;
Authorization authorization;

void setupLocator() {
  locator..registerSingleton(Application())..registerSingleton(Chat())
    ..registerSingleton(Authorization())
    ..registerSingleton(ReceiveMessage())
    ..registerSingleton(TaskService());
  application = locator.get<Application>();
  chat = locator.get<Chat>();
  receiveMessage = locator.get<ReceiveMessage>();
  authorization = locator.get<Authorization>();
}
