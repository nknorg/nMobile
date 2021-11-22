import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/utils/logger.dart';

catchGlobalError(Function? callback, {Function(Object error, StackTrace stack)? onZoneError}) {
  if (!Global.isRelease) {
    callback?.call();
    return;
  }
  // zone
  runZonedGuarded(() async {
    await callback?.call();
  }, (error, stackTrace) async {
    await onZoneError?.call(error, stackTrace);
  }, zoneSpecification: ZoneSpecification(print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
    DateTime now = DateTime.now();
    String format = "${now.hour}:${now.minute}:${now.second}";
    parent.print(zone, "$format：$line");
  }));
  // flutter
  FlutterError.onError = (details, {bool forceReport = false}) {
    if (Settings.debug) {
      // just print
      FlutterError.dumpErrorToConsole(details);
    } else {
      // go onZoneError
      Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.empty);
    }
  };
}

String? handleError(dynamic error, {StackTrace? stackTrace, String? toast}) {
  if (!Global.isRelease) {
    logger.e(error);
    debugPrintStack(maxFrames: 100);
  }
  String? show = getErrorShow(error);
  if (toast?.isNotEmpty == true) {
    Toast.show(toast);
  } else if (show != null && show.isNotEmpty) {
    Toast.show(show);
  }
  return show;
}

String? getErrorShow(dynamic error) {
  if (error == null) return null;

  String loginError = "failed to create client";
  if (error?.toString().contains(loginError) == true) {
    return loginError;
  }
  String rpcError = 'all rpc request failed';
  if (error?.toString().contains(rpcError) == true) {
    return rpcError;
  }
  String txError = 'can not append tx to txpool: not sufficient funds';
  if (error?.toString().contains(txError) == true) {
    return txError;
  }
  String pwdWrong = "wrong password";
  if (error?.toString().contains(pwdWrong) == true) {
    return Global.locale((s) => s.tip_password_error);
  }
  String ksError = "keystore not exits";
  if (error?.toString().contains(ksError) == true) {
    return ksError;
  }
  return Settings.debug ? error.toString() : ""; // Global.locale((s) => s.something_went_wrong)
}
