import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/logger.dart';
import 'hash.dart';

const ADDRESS_GEN_PREFIX = '02b825';
const ADDRESS_GEN_PREFIX_LEN = ADDRESS_GEN_PREFIX.length ~/ 2;
const UINT160_LEN = 20;
const CHECKSUM_LEN = 4;
const SEED_LENGTH = 32;
const ADDRESS_LEN = ADDRESS_GEN_PREFIX_LEN + UINT160_LEN + CHECKSUM_LEN;

copyText(String content, {BuildContext context}) {
  Clipboard.setData(ClipboardData(text: content));
  if (context != null) {
    S _localizations = S.of(context);
    Toast.show(_localizations.copy_success);
  }
}

launchUrl(String url) async {
  try {
    await launch(url, forceSafariVC: false);
  } catch (e) {
    throw e;
  }
}

jsonFormat(raw) {
  Map jsonData;
  try {
    jsonData = jsonDecode(raw);
    return jsonData;
  } on Exception catch (e) {
    logger.e(e);
  }
  return null;
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
  return hexEncode(verifyBytes);
}

bool verifyAddress(String address) {
  try {
    List addressBytes = base58.decode(address);
    if (addressBytes.length != ADDRESS_LEN) {
      return false;
    }
    var addressPrefixBytes = addressBytes.sublist(0, ADDRESS_GEN_PREFIX_LEN);
    var addressPrefix = hexEncode(addressPrefixBytes);
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
