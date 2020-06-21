import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:nmobile/services/background_fetch_service.dart';
import 'package:nmobile/services/task_service.dart';

import 'local_authentication_service.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator
//    ..registerSingleton<NavigateService>(NavigateService())
    ..registerSingleton(BackgroundFetchService())
    ..registerSingleton(TaskService())
    ..registerLazySingleton<Logger>(() => Logger(printer: PrettyPrinter()))
    ..registerLazySingleton(() => LocalAuthenticationService());
}
