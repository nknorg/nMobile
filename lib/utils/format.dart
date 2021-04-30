import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/common/global.dart';

String formatFlowSize(double value, {List<String> unitArr, int decimalDigits = 2}) {
  if (null == value) {
    return '0 ${unitArr[0]}';
  }
  int index = 0;
  while (value > 1024) {
    if (index == unitArr.length - 1) {
      break;
    }
    index++;
    value = value / 1024;
  }
  String size = value.toStringAsFixed(decimalDigits);
  return '$size ${unitArr[index]}';
}

String nknFormat(n, {String symbol, int decimalDigits = 4}) {
  if (n == null) return symbol != null ? '- $symbol' : '-';
  var digit = '#' * decimalDigits;
  var nknPattern = NumberFormat('#,##0.$digit');
  return nknPattern.format(n) + ' ${symbol != null ? symbol : ''}';
}

String timeFormat(DateTime time) {
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
