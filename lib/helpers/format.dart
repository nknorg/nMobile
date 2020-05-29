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
    var localizations = Localizations.localeOf(Global.appContext).toString();
    var diffSpan = time.difference(now);

    if (diffSpan.inSeconds < 0) {
      return '0';
    } else if (diffSpan.inSeconds < 60) {
      return diffSpan.inSeconds.toString();
    } else if (diffSpan.inSeconds < 3600) {
      return formatDurationToTime(diffSpan).toString().substring(3);
    } else if (diffSpan.inHours < 24) {
      return formatDurationToTime(diffSpan);
    } else {
      return diffSpan.inDays.toString() + NMobileLocalizations.of(Global.appContext).day;
    }
  }
  static String durationFormat(Duration d) {
    var localizations = NMobileLocalizations.of(Global.appContext);

    if (d.inSeconds < 0) {
      return '0${localizations.s}';
    } else if (d.inSeconds < 60) {
      return d.inSeconds.toString() + '${localizations.s}';
    } else if (d.inSeconds < 3600) {
      return d.inMinutes.toString() + '${localizations.m}';
    } else if (d.inHours < 24) {
      return d.inHours.toString() + '${localizations.h}';
    } else {
      return d.inDays.toString() + localizations.d;
    }
  }

  static String formatSize(double value) {
    if (null == value) {
      return '0 K';
    }
    List<String> unitArr = ['B', 'KB', 'MB', 'GB', 'TB'];
    int index = 0;
    while (value > 1024) {
      if(index == unitArr.length - 1){
        break;
      }
      index++;
      value = value / 1024;
    }
    String size = value.toStringAsFixed(2);
    return '$size ${unitArr[index]}';
  }
}
