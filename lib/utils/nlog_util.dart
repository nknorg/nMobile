import 'package:logger/logger.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/services/service_locator.dart';

class NLog {
  static void e(dynamic object) {
    try {
      if (!Global.isRelease) instanceOf.get<Logger>().e(object);
    } catch (e) {}
  }

  static void v(dynamic object, {String tag}) {
    try {
      if (!Global.isRelease) instanceOf.get<Logger>().v(object);
    } catch (e) {}
  }

  static void d(dynamic object, {String tag}) {
    try {
      if (!Global.isRelease) instanceOf.get<Logger>().d(object);
    } catch (e) {}
  }

  static void w(dynamic object, {String tag}) {
    if (object == null) {
      return;
    }
    try {
      print('Logger__' + object.toString());
      if (Global.isRelease == false) {}
      // if (!Global.isRelease) {}instanceOf.get<Logger>().w(object.toString());
    } catch (e) {}
  }
}
