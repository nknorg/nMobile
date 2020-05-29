import 'dart:typed_data';

import '../tweetnacl/tweetnaclfast.dart';

Uint8List computeSharedKey(Uint8List myCurveSecretKey, Uint8List otherCurvePubkey){
  return new Box(otherCurvePubkey, myCurveSecretKey).before();
}

Uint8List decrypt(Uint8List encrypted, Uint8List nonce, Uint8List key) {
  return SecretBox(key).open_nonce(encrypted, nonce);
}

Uint8List encrypt(Uint8List message, Uint8List nonce, Uint8List key) {
  return SecretBox(key).box_nonce(message, nonce);
}
