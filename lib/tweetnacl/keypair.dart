import 'dart:typed_data';

class KeyPair {
  Uint8List _publicKey;
  Uint8List _secretKey;

  KeyPair(publicKeyLength, secretKeyLength) {
    _publicKey = Uint8List(publicKeyLength);
    _secretKey = Uint8List(secretKeyLength);
  }

  Uint8List get publicKey => _publicKey;

  Uint8List get secretKey => _secretKey;
}
