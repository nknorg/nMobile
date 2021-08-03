import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
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

void handleError(
  dynamic error, {
  StackTrace? stackTrace,
  String? toast,
}) {
  if (!Global.isRelease) {
    logger.e(error);
    debugPrintStack(maxFrames: 100);
  }
  String? show = getErrorShow(error);
  if (show != null && show.isNotEmpty) {
    Toast.show(show);
  } else if (toast?.isNotEmpty == true) {
    Toast.show(toast);
  }
}

String? getErrorShow(dynamic error) {
  if (error == null) return null;
  S _localizations = S.of(Global.appContext);

  String pwdWrong = "wrong password";
  if (error.message == pwdWrong || error.toString() == pwdWrong) {
    return _localizations.tip_password_error;
  }
  String txError = 'INTERNAL ERROR, can not append tx to txpool: not sufficient funds';
  if (error.message == txError || error.toString() == txError) {
    return txError;
  }
  String rpcError = 'all rpc request failed';
  if (error.message == rpcError || error.toString() == rpcError) {
    return rpcError;
  }
  String ksError = "keystore not exits";
  if (error.message == ksError || error.toString() == ksError) {
    return ksError;
  }
  return Settings.debug ? error.message : _localizations.something_went_wrong;
}
