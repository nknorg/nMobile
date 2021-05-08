import 'dart:convert';
import 'dart:io';

import 'package:base_x/base_x.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:nkn_sdk_flutter/utils/hex.dart';

final String ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
final base58 = BaseXCodec(ALPHABET);
List<int> sha1(raw) {
  var byte;
  if (raw is List<int>)
    byte = raw;
  else if (raw is String) byte = utf8.encode(raw);
  return crypto.sha1.convert(byte).bytes;
}

List<int> sha1Hex(raw) {
  var byte;
  if (raw is List<int>)
    byte = raw;
  else if (raw is String) byte = hexDecode(raw);
  return crypto.sha1.convert(byte).bytes;
}

Future<String> sha1File(File f) async {
  List<int> buffer = [];
  await for (var d in crypto.sha1.bind(f.openRead())) {
    buffer.addAll(d.bytes);
  }
  return hex.encode(buffer);
}

List<int> sha256(raw) {
  var byte;
  if (raw is List<int>)
    byte = raw;
  else if (raw is String) byte = utf8.encode(raw);
  return crypto.sha256.convert(byte).bytes;
}

List<int> sha256Hex(raw) {
  var byte;
  if (raw is List<int>)
    byte = raw;
  else if (raw is String) byte = hexDecode(raw);
  return crypto.sha256.convert(byte).bytes;
}

List<int> doubleSha256(raw) {
  return sha256(sha256(raw));
}

List<int> doubleSha256Hex(String raw) {
  return sha256(sha256(hexDecode(raw)));
}
