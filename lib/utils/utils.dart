import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:url_launcher/url_launcher.dart';

const ADDRESS_GEN_PREFIX = '02b825';
const ADDRESS_GEN_PREFIX_LEN = ADDRESS_GEN_PREFIX.length ~/ 2;
const UINT160_LEN = 20;
const CHECKSUM_LEN = 4;
const SEED_LENGTH = 32;
const ADDRESS_LEN = ADDRESS_GEN_PREFIX_LEN + UINT160_LEN + CHECKSUM_LEN;

void copyText(String? content, {BuildContext? context}) {
  Clipboard.setData(ClipboardData(text: content));
  if (context != null) {
    S _localizations = S.of(context);
    Toast.show(_localizations.copy_success);
  }
}

void launchUrl(String? url) async {
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

// TODO:GG check
String? getPubKeyFromTopicOrChatId(String s) {
  final i = s.lastIndexOf('.');
  final pubKey = i >= 0 ? s.substring(i + 1) : s;
  return Validate.isNknPublicKey(pubKey) ? pubKey : null;
}

String genTopicHash(String topic) {
  var t = topic.replaceFirst(RegExp(r'^#*'), '');
  return 'dchat' + hexEncode(Uint8List.fromList(sha1(t)));
}

num? getNumByValueDouble(double? value, int fractionDigits) {
  if (value == null) return null;
  String valueStr = value.toStringAsFixed(fractionDigits);
  return fractionDigits == 0 ? int.tryParse(valueStr) : double.tryParse(valueStr);
}
