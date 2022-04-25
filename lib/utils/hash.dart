import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:nkn_sdk_flutter/utils/hex.dart';

class Hash {
  static List<int> sha1(dynamic raw) {
    var byte;
    if (raw is List<int>)
      byte = raw;
    else if (raw is String) byte = utf8.encode(raw);
    return crypto.sha1.convert(byte).bytes;
  }

  static List<int> sha1Hex(dynamic raw) {
    var byte;
    if (raw is List<int>)
      byte = raw;
    else if (raw is String) byte = hexDecode(raw);
    return crypto.sha1.convert(byte).bytes;
  }

  static Future<String> sha1File(File f) async {
    List<int> buffer = [];
    await for (var d in crypto.sha1.bind(f.openRead())) {
      buffer.addAll(d.bytes);
    }
    return hex.encode(buffer);
  }

  static List<int> sha256(dynamic raw) {
    var byte;
    if (raw is List<int>)
      byte = raw;
    else if (raw is String) byte = utf8.encode(raw);
    return crypto.sha256.convert(byte).bytes;
  }

  static List<int> sha256Hex(dynamic raw) {
    var byte;
    if (raw is List<int>)
      byte = raw;
    else if (raw is String) byte = hexDecode(raw);
    return crypto.sha256.convert(byte).bytes;
  }

  static List<int> doubleSha256(dynamic raw) {
    return sha256(sha256(raw));
  }

  static List<int> doubleSha256Hex(String raw) {
    return sha256(sha256(hexDecode(raw)));
  }
}
