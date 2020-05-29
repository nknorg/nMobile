import 'dart:typed_data';
import 'signature.dart';
import 'tweetnaclfast.dart';
import 'package:convert/convert.dart';

Uint8List randomByte() {
  return TweetNaclFast.randombytes(Signature.seedLength);
}

String hexEncodeToString(Uint8List raw) {
  return hex.encode(raw).toLowerCase();
}

Uint8List hexDecode(String s) {
  return hex.decode(s);
}
