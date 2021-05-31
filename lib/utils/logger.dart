import 'package:logger/logger.dart';

Logger logger = Logger(printer: PrettyPrinter());

mixin Tag {
  String get TAG => _tagInner(32, 5);

  String _tagInner(int length, int lenHashCode) {
    final String name = this.runtimeType.toString() + '@' + hashCode.toString().substring(0, lenHashCode);
    return name;
    // if (name.length > length) {
    //   return name.substring(name.length - length);
    // } else
    //   return name.padLeft(length, '.');
  }
}
