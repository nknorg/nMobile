import 'dart:typed_data';

import 'package:convert/convert.dart';

/// hexEncode returns the hexadecimal encoding of raw.
String hexEncode(Uint8List raw) {
  return hex.encode(raw).toLowerCase();
}

/// hexDecode returns the bytes represented by the hexadecimal string s.
///
/// hexDecode expects that src contains only hexadecimal
/// characters and that src has even length.
/// If the input is malformed, DecodeString returns
/// the bytes decoded before the error.
Uint8List hexDecode(String s) {
  return Uint8List.fromList(hex.decode(s));
}
