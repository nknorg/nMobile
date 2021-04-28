import 'package:get_it/get_it.dart';
import '../services/task_service.dart';

import 'application.dart';
import 'authentication.dart';
import 'chat.dart';

GetIt locator = GetIt.instance;

Application application;
Chat chat;
Authorization authorization;

void setupLocator() {
  locator..registerSingleton(Application())..registerSingleton(Chat())
    ..registerSingleton(Authorization())
    ..registerSingleton(TaskService());
  application = locator.get<Application>();
  chat = locator.get<Chat>();
  authorization = locator.get<Authorization>();
}
