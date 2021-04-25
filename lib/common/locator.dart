import 'package:get_it/get_it.dart';

import '../services/task_service.dart';
import 'application.dart';

GetIt locator = GetIt.instance;

Application application;

void setupLocator() {
  locator..registerSingleton(Application())..registerSingleton(TaskService());
  application = locator.get<Application>();
}
