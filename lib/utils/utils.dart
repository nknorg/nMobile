import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hash.dart';

const ADDRESS_GEN_PREFIX = '02b825';
const ADDRESS_GEN_PREFIX_LEN = ADDRESS_GEN_PREFIX.length ~/ 2;
const UINT160_LEN = 20;
const CHECKSUM_LEN = 4;
const SEED_LENGTH = 32;
const ADDRESS_LEN = ADDRESS_GEN_PREFIX_LEN + UINT160_LEN + CHECKSUM_LEN;

copyText(String? content, {BuildContext? context}) {
  Clipboard.setData(ClipboardData(text: content));
  if (context != null) {
    S _localizations = S.of(context);
    Toast.show(_localizations.copy_success);
  }
}

launchUrl(String? url) async {
  if (url == null || url.isEmpty) return;
  try {
    await launch(url, forceSafariVC: false);
  } catch (e) {
    throw e;
  }
}

Map<String, dynamic>? jsonFormat(raw) {
  Map<String, dynamic> jsonData;
  try {
    jsonData = jsonDecode(raw);
    return jsonData;
  } on Exception catch (e) {
    handleError(e);
  }
  return null;
}

bool isDChatByClientAddress(String clientAddress) {
  return clientAddress.length > 64;
}

String getPublicKeyByClientAddr(String addr) {
  int n = addr.lastIndexOf('.');
  if (n < 0) {
    return addr;
  } else {
    return addr.substring(n + 1);
  }
}

String addressStringToProgramHash(String address) {
  var addressBytes = base58.decode(address);
  var programHashBytes = addressBytes.sublist(ADDRESS_GEN_PREFIX_LEN, addressBytes.length - CHECKSUM_LEN);
  return hexEncode(programHashBytes);
}

String getAddressStringVerifyCode(String address) {
  var addressBytes = base58.decode(address);
  var verifyBytes = addressBytes.sublist(addressBytes.length - CHECKSUM_LEN);
  return hexEncode(verifyBytes);
}

List<int> genAddressVerifyBytesFromProgramHash(String programHash) {
  programHash = ADDRESS_GEN_PREFIX + programHash;
  var verifyBytes = doubleSha256Hex(programHash);
  return verifyBytes.sublist(0, CHECKSUM_LEN);
}

String genAddressVerifyCodeFromProgramHash(String programHash) {
  var verifyBytes = genAddressVerifyBytesFromProgramHash(programHash);
  return hexEncode(Uint8List.fromList(verifyBytes));
}

bool verifyAddress(String address) {
  try {
    Uint8List addressBytes = base58.decode(address);
    if (addressBytes.length != ADDRESS_LEN) {
      return false;
    }
    var addressPrefixBytes = addressBytes.sublist(0, ADDRESS_GEN_PREFIX_LEN);
    var addressPrefix = hexEncode(Uint8List.fromList(addressPrefixBytes));
    if (addressPrefix != ADDRESS_GEN_PREFIX) {
      return false;
    }
    var programHash = addressStringToProgramHash(address);
    var addressVerifyCode = getAddressStringVerifyCode(address);
    var programHashVerifyCode = genAddressVerifyCodeFromProgramHash(programHash);
    return addressVerifyCode == programHashVerifyCode;
  } catch (e) {
    return false;
  }
}

final privateTopicRegExp = RegExp(r'\.[0-9a-f]{64}$');

bool isPrivateTopicReg(String topic) {
  return privateTopicRegExp.hasMatch(topic);
}

unLeadingHashIt(String str) {
  return str.replaceFirst(RegExp(r'^#*'), '');
}

String? genTopicHash(String? topic) {
  if (topic == null || topic.isEmpty) {
    return null;
  }
  var t = unLeadingHashIt(topic);
  return 'dchat' + hexEncode(Uint8List.fromList(sha1(t)));
}

num? getNumByValueDouble(double? value, int fractionDigits) {
  if (value == null) return null;
  String valueStr = value.toStringAsFixed(fractionDigits);
  return fractionDigits == 0 ? int.tryParse(valueStr) : double.tryParse(valueStr);
}
