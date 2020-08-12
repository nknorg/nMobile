import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class Format {
  static String nknFormat(n, {String symbol, int decimalDigits = 4}) {
    if (n == null) return symbol != null ? '- $symbol' : '-';
    var digit = '#' * decimalDigits;
    var nknPattern = NumberFormat('#,##0.$digit');
    return nknPattern.format(n) + ' ${symbol != null ? symbol : ''}';
  }

  static String currencyFormat(n, {String symbol, int decimalDigits = 4}) {
    if (n == null) return symbol != null ? '-' : '- $symbol';
    var digit = '#' * decimalDigits;
    var currencyPattern = NumberFormat('#,##0.$digit');
    return currencyPattern.format(n) + ' ${symbol != null ? symbol : ''}';
  }

  static String timeFormat(DateTime time) {
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

  static String formatDurationToTime(Duration d) {
    return d.toString().split('.').first.padLeft(8, "0");
  }

  static String timeFromNowFormat(DateTime time) {
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
      return diff.inDays.toString() + NL10ns.of(Global.appContext).days;
    } else {
      return (diff.inDays / 7).toStringAsFixed(0) + NL10ns.of(Global.appContext).weeks;
    }
  }

  static String durationFormat(Duration d) {
    var localizations = NL10ns.of(Global.appContext);
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

  static String formatSize(double value) {
    if (null == value) {
      return '0 K';
    }
    List<String> unitArr = ['B', 'KB', 'MB', 'GB'];
    int index = 0;
    while (value > 1024) {
      index++;
      value = value / 1024;
    }
    String size = value.toStringAsFixed(2);
    return '$size ${unitArr[index]}';
  }
}
