import 'package:catcher/catcher_plugin.dart';

CatcherOptions debugOptions = CatcherOptions(PageReportMode(), [ConsoleHandler()]);

CatcherOptions releaseOptions = CatcherOptions(SilentReportMode(), [

]);
