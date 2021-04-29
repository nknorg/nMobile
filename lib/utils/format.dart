import 'package:intl/intl.dart';

String formatFlowSize(double value, {List<String> unitArr, int decimalDigits = 2}) {
  if (null == value) {
    return '0 ${unitArr[0]}';
  }
  int index = 0;
  while (value > 1024) {
    if(index == unitArr.length - 1){
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