import 'package:intl/intl.dart';

class Format {
  static RegExp chatRegSpecial = new RegExp("@[^ \\s!-,/:-?\\[-^`{-~，。？！（）【】《》“”：；、]+");
  static RegExp chatRegEmail = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

  static List<String> chatText(String? str) {
    List<String> result = [];
    if (str == null || str.length == 0 || str.contains('&status=approve')) return result;

    if (str.contains(chatRegSpecial) && !str.contains(chatRegEmail)) {
      List<String> spp = str.split(" ");

      // if (spp.firstWhere((x) => x.toString().contains(chatRegEmail), orElse: () => "") != "") {
      //   return result;
      // }

      for (String s in spp) {
        result.add(s);
        result.add(" ");
      }
      return result;
    }
    return result;
  }

  static String nknBalance(n, {String? symbol, int decimalDigits = 4}) {
    if (n == null) return symbol != null ? '- $symbol' : '-';
    var digit = '#' * decimalDigits;
    var nknPattern = NumberFormat('#,##0.$digit');
    return nknPattern.format(n) + ' ${symbol != null ? symbol : ''}';
  }

  static String flowSize(double? value, {required List<String> unitArr, int decimalDigits = 2}) {
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
}
