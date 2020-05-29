import 'dart:typed_data';

import 'tweetnaclfast.dart';

import 'keypair.dart';

class Signature {
  //Length of signing public key in bytes.
  static final int publicKeyLength = 32;

  //Length of signing secret key in bytes.
  static final int secretKeyLength = 64;

  //Length of seed for nacl.sign.keyPair.fromSeed in bytes.
  static final int seedLength = 32;

  //Length of signature in bytes.
  static final int signatureLength = 64;

  Uint8List _theirPublicKey;
  Uint8List _mySecretKey;

  Signature(this._theirPublicKey, this._mySecretKey);

  /*
   *   Signs the message using the secret key and returns a signed message.
   * */
  Uint8List sign(Uint8List message) {
    if (message == null) return null;

    return sign_len(message, 0, message.length);
  }

  Uint8List sign_off(Uint8List message, final int moff) {
    if (!(message != null && message.length > moff)) return null;

    return sign_len(message, moff, message.length - moff);
  }

  Uint8List sign_len(Uint8List message, final int moff, final int mlen) {
    // check message
    if (!(message != null && message.length >= (moff + mlen))) return null;

    // signed message
    Uint8List sm = Uint8List(mlen + signatureLength);

    TweetNaclFast.crypto_sign(sm, -1, message, moff, mlen, _mySecretKey);

    return sm;
  }

  /*
   *   Verifies the signed message and returns the message without signature.
   *   Returns null if verification failed.
   * */
  Uint8List open(Uint8List signedMessage) {
    if (signedMessage == null) return null;

    return open_len(signedMessage, 0, signedMessage.length);
  }

  Uint8List open_off(Uint8List signedMessage, final int smoff) {
    if (!(signedMessage != null && signedMessage.length > smoff)) return null;

    return open_len(signedMessage, smoff, signedMessage.length - smoff);
  }

  Uint8List open_len(Uint8List signedMessage, final int smoff, final int smlen) {
    // check sm length
    if (!(signedMessage != null &&
        signedMessage.length >= (smoff + smlen) &&
        smlen >= signatureLength)) return null;

    // temp buffer
    Uint8List tmp = Uint8List(smlen);

    if (0 !=
        TweetNaclFast.crypto_sign_open(tmp, -1, signedMessage, smoff, smlen, _theirPublicKey))
      return null;

    // message
    Uint8List msg = Uint8List(smlen - signatureLength);
    for (int i = 0; i < msg.length; i++)
      msg[i] = signedMessage[smoff + i + signatureLength];

    return msg;
  }

  /*
   *   Signs the message using the secret key and returns a signature.
   * */
  Uint8List detached(Uint8List message) {
    Uint8List signedMsg = this.sign(message);
    Uint8List sig = Uint8List(signatureLength);
    for (int i = 0; i < sig.length; i++) sig[i] = signedMsg[i];
    return sig;
  }

  /*
   *   Verifies the signature for the message and
   *   returns true if verification succeeded or false if it failed.
   * */
  bool detached_verify(Uint8List message, Uint8List signature) {
    if (signature.length != signatureLength) return false;
    if (_theirPublicKey.length != publicKeyLength) return false;
    Uint8List sm = Uint8List(signatureLength + message.length);
    Uint8List m = Uint8List(signatureLength + message.length);
    for (int i = 0; i < signatureLength; i++) sm[i] = signature[i];
    for (int i = 0; i < message.length; i++)
      sm[i + signatureLength] = message[i];
    return (TweetNaclFast.crypto_sign_open(m, -1, sm, 0, sm.length, _theirPublicKey) >= 0);
  }

  /*
   *   Signs the message using the secret key and returns a signed message.
   * */
  static KeyPair keyPair() {
    KeyPair kp = new KeyPair(publicKeyLength, secretKeyLength);

    TweetNaclFast.crypto_sign_keypair(kp.publicKey, kp.secretKey, false);
    return kp;
  }

  static KeyPair keyPair_fromSecretKey(Uint8List secretKey) {
    KeyPair kp = new KeyPair(publicKeyLength, secretKeyLength);
    Uint8List pk = kp.publicKey;
    Uint8List sk = kp.secretKey;

    // copy sk
    for (int i = 0; i < kp.secretKey.length; i++) sk[i] = secretKey[i];

    // copy pk from sk
    for (int i = 0; i < kp.publicKey.length; i++)
      pk[i] = secretKey[32 + i]; // hard-copy

    return kp;
  }

  static KeyPair keyPair_fromSeed(Uint8List seed) {
    KeyPair kp = new KeyPair(publicKeyLength, secretKeyLength);
    Uint8List pk = kp.publicKey;
    Uint8List sk = kp.secretKey;

    // copy sk
    for (int i = 0; i < seedLength; i++) sk[i] = seed[i];

    // generate pk from sk
    TweetNaclFast.crypto_sign_keypair(pk, sk, true);

    return kp;
  }
}