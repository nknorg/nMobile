import 'package:catcher/catcher.dart';

CatcherOptions debugOptions = CatcherOptions(PageReportMode(), [ConsoleHandler()]);

CatcherOptions releaseOptions = CatcherOptions(SilentReportMode(), [
  EmailAutoHandler('smtp.qq.com', 587, '632987138@qq.com', 'NKN Catcher', 'sdepcgebzkpzbdaf', ['461897266@qq.com'], emailTitle: 'NKN Catcher'),
]);
