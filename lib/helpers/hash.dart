import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:nmobile/helpers/utils.dart';

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
  List<int> buffer = List<int>();
  await for (var d in crypto.sha1.bind(f.openRead())) {
    print('sha1File for loop: ${d.bytes}');
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

unleadingHashIt(String str) {
  return str.replaceFirst(RegExp(r'^#*'), '');
}

genChannelId(String topic) {
  if (topic == null || topic.isEmpty) {
    return null;
  }
  var t = unleadingHashIt(topic);
  return 'dchat' + hexEncode(sha1(t));
}
