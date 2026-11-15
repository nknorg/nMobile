import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

catchGlobalError(Function? callback, {Function(Object error, StackTrace stack)? onZoneError}) {
  if (!Settings.isRelease) {
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
    if (!Settings.isRelease) {
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
  static String writeTCP = "write tcp";
  static String readTCP = "read tcp";
  static String broken = "Broken pipe";
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
    writeTCP,
    readTCP,
    broken,
    writeBroken,
    readBroken,
    wrongNode,
    rpcRequestFail,
    clientClosed,
    invalidPayloadType,
    connectFailed,
    nilWebsocketConn,
    createClientFailed,
    nilClient,
    "new account fail", // same with native
    "client create fail", // same with native
    "client is closed", // same with native
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
}

void handleError(dynamic error, StackTrace? stackTrace, {bool? toast, String? text, bool upload = true}) {
  if (Settings.isRelease) {
    toast = toast ?? false;
    String errStr = error?.toString().toLowerCase() ?? "";
    bool contains = _containsStrings(errStr, [
      "wrong password",
      "biometrics",
      "startRecorder",
      "permission state error",
      "permission_requesting",
      "photo_access_denied",
      "Cannot delete file",
      "fcm.googleapis.com",
      "mainnet.infura.io",
      "eth-mainnet.g.alchemy.com",
      NknError.clientClosed,
      NknError.rpcRequestFail,
    ]);
    if (upload && !contains) {
      if (Settings.sentryEnable) Sentry.captureException(error, stackTrace: stackTrace); // await
    }
  } else if (Settings.debug) {
    toast = toast ?? true;
    logger.e(error);
    debugPrintStack(maxFrames: 100);
  }
  if (toast != true) return;
  text = text ?? getErrorShow(error);
  if ((text != null) && text.isNotEmpty) {
    Toast.show(text);
  }
  return;
}

String? getErrorShow(dynamic error) {
  String errStr = error?.toString().toLowerCase() ?? "";
  if (errStr.contains(NknError.rpcRequestFail)) {
    return null;
  }
  if (errStr.contains("platformexception(")) {
    errStr = errStr.substring(18, errStr.length - 1);
    List<String> splits = errStr.split(",");
    if (splits.length == 4) {
      if (splits[0].trim().isNotEmpty) {
        errStr = splits[0] + ", ";
      } else {
        errStr = "";
      }
      if (splits[1].trim() == splits[2].trim()) {
        errStr = errStr + splits[1];
      } else {
        errStr = errStr + splits[1] + ", " + splits[2];
      }
      if (splits[3].trim() != "null") {
        errStr = errStr + ", " + splits[3];
      }
    }
  }
  if (Settings.debug) return errStr;

  // release
  if (errStr.isEmpty) return "";
  bool contains = _containsStrings(errStr, [
    NknError.rpcRequestFail,
    NknError.broken,
    NknError.writeBroken,
    NknError.readBroken,
    NknError.writeTCP,
    NknError.readTCP,
    "address = mainnet.infura.io",
    "address = eth-mainnet.g.alchemy.com",
    "address = fcm.googleapis.com",
  ]);
  if (contains) return "";

  if (NknError.isNknError(error)) return errStr;
  if (errStr.contains("oom") == true) return "out of memory";
  if (errStr.contains("wrong password") == true) return errStr;
  return "";
  // return Settings.locale((s) => s.something_went_wrong);
  // return error.toString();
}

bool _containsStrings(String parent, List<String> subs) {
  bool contains = false;
  for (var i = 0; i < subs.length; i++) {
    contains = parent.contains(subs[i]);
    if (contains) break;
  }
  return contains;
}
