import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'hex.dart';

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
  var t = unleadingHashIt(topic);
  return 'dchat' + hexEncode(Uint8List.fromList(sha1(t)));
}
