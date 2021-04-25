import 'package:nkn_sdk_flutter/configure.dart';

class NknSdk {
  static config({logger}) {
    if (logger != null) Configure.logger = logger;
  }
}
