import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';

import '../utils/logger.dart';

// TODO:GG global handle

void handleError(
  error, {
  StackTrace stackTrace,
  String toast,
}) {
  logger.e(error);
  debugPrintStack(maxFrames: 20);
  if (error == null) return;
  String show = getErrorShow(error);
  if (show != null && show.isNotEmpty) {
    Toast.show(show);
  } else {
    if (toast != null && toast.isNotEmpty) {
      Toast.show(toast);
    }
  }
}

String getErrorShow(error) {
  if (error == null) return null;
  S _localizations = S.of(Global.appContext);

  String pwdWrong = "wrong password";
  if (error.message == pwdWrong || error.toString() == pwdWrong) {
    return _localizations.password_wrong;
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
  return error.message;
}
