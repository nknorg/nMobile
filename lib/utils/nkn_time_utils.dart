import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NKNTimeUtil {
  static String formatChatTime(BuildContext context, DateTime timestamp) {
    var now = DateTime.now();
    var localizations = Localizations.localeOf(context).toString();
    DateTime time = timestamp ?? now;
    String timeFormat;
    if (now.difference(time).inDays == 0 && time.day == now.day) {
      timeFormat = DateFormat.Hm(localizations).format(time);
    } else if (now.difference(time).inDays <= 7 && time.weekday <= now.weekday) {
      timeFormat = DateFormat.E(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(timestamp);
    } else if (now.difference(time).inDays <= 31 && time.month == time.month) {
      timeFormat = DateFormat.Md(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(timestamp);
    } else {
      timeFormat = DateFormat.yMd(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(timestamp);
    }

    return timeFormat;
  }
}
