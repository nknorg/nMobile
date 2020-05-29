import 'package:intl/intl.dart';
import 'package:nmobile/helpers/global.dart';

class NknDateUtil {
  static String getNewDate(DateTime time) {
    return DateFormat("EEE, MM dd yyyy", Global.locale == 'zh' ? 'zh' : 'en')
        .format(time);
  }
}
