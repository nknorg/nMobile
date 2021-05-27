import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/generated/l10n.dart';

String nknFormat(n, {String? symbol, int decimalDigits = 4}) {
  if (n == null) return symbol != null ? '- $symbol' : '-';
  var digit = '#' * decimalDigits;
  var nknPattern = NumberFormat('#,##0.$digit');
  return nknPattern.format(n) + ' ${symbol != null ? symbol : ''}';
}

String formatFlowSize(double? value, {required List<String> unitArr, int decimalDigits = 2}) {
  if (value == null) {
    return '0 ${unitArr[0]}';
  }
  int index = 0;
  while (value! > 1024) {
    if (index == unitArr.length - 1) {
      break;
    }
    index++;
    value = value / 1024;
  }
  String size = value.toStringAsFixed(decimalDigits);
  return '$size ${unitArr[index]}';
}

String dateFormat(DateTime? time) {
  if (time == null) return "";
  return DateFormat("EEE, MM dd yyyy", Settings.locale == 'zh' ? 'zh' : 'en').format(time);
}

String timeFormat(DateTime? time) {
  if (time == null) return "";
  var now = DateTime.now();
  var localizations = Localizations.localeOf(Global.appContext).toString();
  if (now.difference(time).inDays == 0 && time.day == now.day) {
    return DateFormat.Hm(localizations).format(time);
  } else if (now.difference(time).inDays <= 7 && time.weekday <= now.weekday) {
    return DateFormat.E(localizations).format(time);
  } else if (now.difference(time).inDays <= 31 && time.month == time.month) {
    return DateFormat.Md(localizations).format(time);
  } else {
    return DateFormat.yMd(localizations).format(time);
  }
}

String formatChatTime(DateTime? timestamp) {
  var now = DateTime.now();
  var localizations = Localizations.localeOf(Global.appContext).toString();
  DateTime time = timestamp ?? now;
  String timeFormat;
  if (now.difference(time).inDays == 0 && time.day == now.day) {
    timeFormat = DateFormat.Hm(localizations).format(time);
  } else if (now.difference(time).inDays <= 7 && time.weekday <= now.weekday) {
    timeFormat = DateFormat.E(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(time);
  } else if (now.difference(time).inDays <= 31 && time.month == time.month) {
    timeFormat = DateFormat.Md(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(time);
  } else {
    timeFormat = DateFormat.yMd(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(time);
  }

  return timeFormat;
}

String timeFromNowFormat(DateTime? time) {
  if (time == null) return "";
  var now = DateTime.now();
  var diff = time.difference(now);

  if (diff.inSeconds < 0) {
    return '0';
  } else if (diff.inSeconds < Duration.secondsPerMinute) {
    return diff.inSeconds.toString();
  } else if (diff.inMinutes < Duration.minutesPerHour) {
    return formatDurationToTime(diff).toString().substring(3);
  } else if (diff.inHours < Duration.hoursPerDay) {
    return formatDurationToTime(diff);
  } else if (diff.inDays < 7) {
    return diff.inDays.toString() + ' ' + S.of(Global.appContext).days;
  } else {
    return (diff.inDays / 7).toStringAsFixed(0) + ' ' + S.of(Global.appContext).weeks;
  }
}

String formatDurationToTime(Duration d) {
  return d.toString().split('.').first.padLeft(8, "0");
}

String durationFormat(Duration d) {
  var localizations = S.of(Global.appContext);
  if (d.inSeconds < 0) {
    return '0 ${localizations.seconds}';
  } else if (d.inSeconds < Duration.secondsPerMinute) {
    return d.inSeconds.toString() + ' ${localizations.seconds}';
  } else if (d.inMinutes < Duration.minutesPerHour) {
    return d.inMinutes.toString() + ' ${localizations.minutes}';
  } else if (d.inHours < Duration.hoursPerDay) {
    return d.inHours.toString() + ' ${localizations.hours}';
  } else if (d.inDays < 7) {
    return d.inDays.toString() + ' ' + localizations.days;
  } else {
    return (d.inDays / 7).toStringAsFixed(0) + ' ' + localizations.weeks;
  }
}
