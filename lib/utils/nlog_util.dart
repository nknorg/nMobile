import 'package:logger/logger.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/services/service_locator.dart';

class NLog {
  static void e(dynamic object) {
    if (!Global.isRelease) locator.get<Logger>().e(object);
  }

  static void v(dynamic object, {String tag}) {
    if (!Global.isRelease) locator.get<Logger>().v(object);
  }

  static void d(dynamic object, {String tag}) {
    if (!Global.isRelease) locator.get<Logger>().d(object);
  }

  static void w(dynamic object, {String tag}) {
    if (!Global.isRelease) locator.get<Logger>().w(object);
  }
}
