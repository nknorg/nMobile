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

class NknError {
  // sdk
  static String writeBroken = "write: broken pipe";
  static String readBroken = "read: broken pipe";
  static String keystoreNotExits = "keystore not exits";

  // nkn-sdk
  static String wrongNode = "wrong node";
  static String appendTxPoolFail = "can not append tx to txpool";

  // nkn-sdk-go
  static String rpcRequestFail = "all rpc request failed";
  static String clientClosed = "use of closed network connection";
  static String keyNotInMap = "key not in map";
  static String invalidPayloadType = "invalid payload type";
  static String connectFailed = "connect failed";
  static String noDestination = "no destination";
  static String invalidDestination = "invalid destination";
  static String invalidPubkeyOrName = "invalid public key or name";
  static String invalidPubkeySize = "invalid public key size";
  static String invalidPubkey = "invalid public key";
  static String messageOversize = "encoded message is greater than";
  static String nilWebsocketConn = "nil websocket connection";
  static String decryptFailed = "decrypt message failed";
  static String addrNotAllowed = "address not allowed";
  static String createClientFailed = "failed to create client";
  static String nilClient = "client is nil";
  static String notNanoPay = "not nano pay transaction";
  static String wrongRecipient = "wrong nano pay recipient";
  static String nanoPayClosed = "use of closed nano pay claimer";
  static String insufficientBalance = "insufficient balance";
  static String invalidAmount = "invalid amount";
  static String expiredNanoPay = "nanopay expired";
  static String expiredNanoPayTxn = "nanopay transaction expired";
  static String wrongPassword = "wrong password";
  static String invalidWalletVersion = "invalid wallet version";
  static String unencryptedMessage = "message is unencrypted";

  static List<String> clientErrors = [
    writeBroken,
    wrongNode,
    rpcRequestFail,
    clientClosed,
    invalidPayloadType,
    connectFailed,
    nilWebsocketConn,
    createClientFailed,
    nilClient,
  ];

  static List<String> nknErrors = [
    ...clientErrors,
    keystoreNotExits,
    appendTxPoolFail,
    keyNotInMap,
    noDestination,
    invalidDestination,
    invalidPubkeyOrName,
    invalidPubkeySize,
    invalidPubkey,
    messageOversize,
    decryptFailed,
    addrNotAllowed,
    notNanoPay,
    wrongRecipient,
    nanoPayClosed,
    insufficientBalance,
    invalidAmount,
    expiredNanoPay,
    expiredNanoPayTxn,
    wrongPassword,
    invalidWalletVersion,
    unencryptedMessage,
  ];

  static bool isNknError(dynamic e) {
    String errStr = e?.toString().toLowerCase() ?? "";
    bool isClientError = false;
    NknError.nknErrors.forEach((element) {
      if (errStr.contains(element) == true) {
        isClientError = true;
      }
    });
    return isClientError;
  }

  static bool isClientError(dynamic e) {
    String errStr = e?.toString().toLowerCase() ?? "";
    bool isClientError = false;
    NknError.clientErrors.forEach((element) {
      if (errStr.contains(element) == true) {
        isClientError = true;
      }
    });
    return isClientError;
  }
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
  String errStr = error?.toString().toLowerCase() ?? "";
  if (errStr.isEmpty) return "";

  if (NknError.isNknError(error)) return errStr;
  if (errStr.contains("oom") == true) return "out of memory";
  return Settings.debug ? error.toString() : ""; // Global.locale((s) => s.something_went_wrong)
}
