import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/utils/base_x.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:web3dart/credentials.dart';

class Validate {
  static const ADDRESS_GEN_PREFIX = '02b825';
  static const ADDRESS_GEN_PREFIX_LEN = ADDRESS_GEN_PREFIX.length ~/ 2;
  static const UINT160_LEN = 20;
  static const CHECKSUM_LEN = 4;
  static const SEED_LENGTH = 32;
  static const ADDRESS_LEN = ADDRESS_GEN_PREFIX_LEN + UINT160_LEN + CHECKSUM_LEN;

  static final String ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static final base58 = BaseXCodec(ALPHABET);

  // static final regAddress = RegExp('NKN[0-9A-Za-z]{33}');
  static isNknAddressOk(String? address) {
    if (address == null || address.isEmpty) return false;
    try {
      Uint8List addressBytes = base58.decode(address);
      if (addressBytes.length != ADDRESS_LEN) {
        return false;
      }
      var addressPrefixBytes = addressBytes.sublist(0, ADDRESS_GEN_PREFIX_LEN);
      var addressPrefix = hexEncode(Uint8List.fromList(addressPrefixBytes));
      if (addressPrefix != ADDRESS_GEN_PREFIX) {
        return false;
      }
      var programHash = addressStringToProgramHash(address);
      var addressVerifyCode = getAddressStringVerifyCode(address);
      var programHashVerifyCode = genAddressVerifyCodeFromProgramHash(programHash);
      return addressVerifyCode == programHashVerifyCode;
    } catch (e) {
      return false;
    }
  }

  static String addressStringToProgramHash(String address) {
    var addressBytes = base58.decode(address);
    var programHashBytes = addressBytes.sublist(ADDRESS_GEN_PREFIX_LEN, addressBytes.length - CHECKSUM_LEN);
    return hexEncode(programHashBytes);
  }

  static String getAddressStringVerifyCode(String address) {
    var addressBytes = base58.decode(address);
    var verifyBytes = addressBytes.sublist(addressBytes.length - CHECKSUM_LEN);
    return hexEncode(verifyBytes);
  }

  static List<int> genAddressVerifyBytesFromProgramHash(String programHash) {
    programHash = ADDRESS_GEN_PREFIX + programHash;
    var verifyBytes = Hash.doubleSha256Hex(programHash);
    return verifyBytes.sublist(0, CHECKSUM_LEN);
  }

  static String genAddressVerifyCodeFromProgramHash(String programHash) {
    var verifyBytes = genAddressVerifyBytesFromProgramHash(programHash);
    return hexEncode(Uint8List.fromList(verifyBytes));
  }

  static isEthAddressOk(String? address) {
    if (address == null || address.isEmpty) return false;
    try {
      EthereumAddress.fromHex(address.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  static final regPubKey = RegExp("[0-9A-Fa-f]{64}");
  static isNknPublicKey(String? publicKey) {
    if (publicKey == null || publicKey.isEmpty || (publicKey.length != 64)) return false;
    return regPubKey.hasMatch(publicKey);
  }

  static isEthPublicKey(String? publicKey) {
    if (publicKey == null || publicKey.isEmpty) return false;
    return publicKey.length >= 50;
  }

  static final regSeed = RegExp(r'^[0-9A-Fa-f]{64}$');
  static bool isNknSeedOk(String? seed) {
    if (seed == null || seed.isEmpty || (seed.length != 64)) return false;
    return regSeed.hasMatch(seed);
  }

  static bool isEthSeedOk(String? seed) {
    if (seed == null || seed.isEmpty) return false;
    return seed.length >= 50;
  }

  static final regWalletAmount = RegExp(r'^[0-9]+\.?[0-9]{0,8}');
  static isNknAmountOk(String? amount) {
    if (amount == null || amount.isEmpty) return false;
    return regWalletAmount.hasMatch(amount);
  }

  static final regChatIdentifier = RegExp(r'^[^.]*.?[0-9A-Fa-f]{64}$');
  static isNknChatIdentifierOk(String? identifier) {
    if (identifier == null || identifier.isEmpty) return false;
    List<String> splits = identifier.split(".");
    if (splits.length > 0) {
      if (splits[splits.length - 1].length != 64) return false;
    }
    return regChatIdentifier.hasMatch(identifier);
  }

  static final regPrivateTopic = RegExp(r'\.[0-9A-Fa-f]{64}$');
  static bool isPrivateTopicOk(String? topic) {
    if (topic == null || topic.isEmpty) return false;
    return regPrivateTopic.hasMatch(topic);
  }
}
