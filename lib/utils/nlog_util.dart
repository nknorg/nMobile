import 'package:logger/logger.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/services/service_locator.dart';

class NLog {
  static void e(dynamic object) {
    try {
      if (!Global.isRelease) locator.get<Logger>().e(object);
    } catch (e) {}
  }

  static void v(dynamic object, {String tag}) {
    try {
      if (!Global.isRelease) locator.get<Logger>().v(object);
    } catch (e) {}
  }

  static void d(dynamic object, {String tag}) {
    try {
      if (!Global.isRelease) locator.get<Logger>().d(object);
    } catch (e) {}
  }

  static void w(dynamic object, {String tag}) {
    try {
      if (!Global.isRelease) locator.get<Logger>().w(object);
    } catch (e) {}
  }
}
