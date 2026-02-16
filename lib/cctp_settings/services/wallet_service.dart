import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart' as ed25519_hd_key;
import 'package:hex/hex.dart';
import 'package:bs58/bs58.dart' as bs58;
import 'package:web3dart/web3dart.dart';
import 'package:solana/solana.dart' as solana;
import 'package:bip32/bip32.dart' as bip32;

/// Mock Solana keypair for demonstration purposes
class MockSolanaKeypair {
  final String privateKey;
  final String publicKey;

  const MockSolanaKeypair({required this.privateKey, required this.publicKey});

  @override
  String toString() =>
      'SolanaKeypair(privateKey: $privateKey, publicKey: $publicKey)';
}

// KeyData class to hold derived key information
class KeyData {
  final Uint8List key;
  final Uint8List chainCode;

  KeyData(this.key, this.chainCode);
}

// Extension to add hex encoding/decoding to Uint8List
extension HexExtension on Uint8List {
  String toHex() => HEX.encode(this);
}

// Extension to add hex encoding/decoding to List<int>
extension HexListExtension on List<int> {
  String toHex() => HEX.encode(this);
}

extension HexStringExtension on String {
  Uint8List hexToBytes() => Uint8List.fromList(HEX.decode(this));

  List<int> decodeHex() => HEX.decode(this);
}

class WalletService {
  String? _mnemonic;
  String? _ethereumAddress;
  String? _solanaAddress;
  Credentials? _ethCreds; // cache derived creds to keep signer consistent
  Uint8List?
      _solanaPrivateKey32; // in-memory cache of derived Solana 32-byte private key

  WalletService({String? mnemonic}) : _mnemonic = mnemonic;

  /// Sets the mnemonic for the wallet
  void setMnemonic(String mnemonic) {
    _mnemonic = mnemonic;
    // Clear cached addresses when mnemonic changes
    _ethereumAddress = null;
    _solanaAddress = null;
    _ethCreds = null;
    _solanaPrivateKey32 = null;
  }

  /// Validates a BIP39 mnemonic phrase
  static bool validateMnemonic(String mnemonic) {
    try {
      return bip39.validateMnemonic(mnemonic);
    } catch (e) {
      return false;
    }
  }

  /// Derives Ethereum address from mnemonic
  Future<String> getEthereumAddress() async {
    if (_ethereumAddress != null) return _ethereumAddress!;

    if (_mnemonic == null) {
      throw Exception('No mnemonic provided');
    }

    // Generate seed from mnemonic
    final seed = bip39.mnemonicToSeed(_mnemonic!);

    // Use BIP32 to derive the private key for Ethereum (m/44'/60'/0'/0/0)
    final root = bip32.BIP32.fromSeed(seed);
    final ethChild = root.derivePath("m/44'/60'/0'/0/0");

    if (ethChild.privateKey == null) {
      throw Exception('Failed to derive Ethereum private key');
    }

    // Create Ethereum credentials and get address
    _ethCreds = EthPrivateKey.fromHex(HEX.encode(ethChild.privateKey!));
    _ethereumAddress = _ethCreds!.address.hex;

    return _ethereumAddress!;
  }

  /// Derives Solana address from mnemonic
  Future<String> getSolanaAddress() async {
    if (_solanaAddress != null) return _solanaAddress!;

    if (_mnemonic == null) {
      throw Exception('No mnemonic provided');
    }

    // TODO: Implement proper Solana address derivation when solana package is properly configured
    _solanaAddress = "Solana address derivation not yet implemented";

    return _solanaAddress!;
  }

  /// Gets the Ethereum private key (hex encoded)
  Future<String> getEthereumPrivateKey() async {
    if (_mnemonic == null) {
      throw Exception('No mnemonic provided');
    }

    // Generate seed from mnemonic
    final seed = bip39.mnemonicToSeed(_mnemonic!);

    // Use BIP32 to derive the private key for Ethereum (m/44'/60'/0'/0/0)
    final root = bip32.BIP32.fromSeed(seed);
    final ethChild = root.derivePath("m/44'/60'/0'/0/0");

    if (ethChild.privateKey == null) {
      throw Exception('Failed to derive Ethereum private key');
    }

    return HEX.encode(ethChild.privateKey!);
  }

  /// Gets the Ethereum credentials for signing
  Future<Credentials> getEthereumCredentials() async {
    if (_ethCreds == null) {
      await getEthereumAddress(); // This will derive and cache the credentials
    }

    if (_ethCreds == null) {
      throw Exception('Failed to derive Ethereum credentials');
    }

    return _ethCreds!;
  }

  /// Gets all derived addresses in a map
  Future<Map<String, String>> getAllAddresses() async {
    final addresses = <String, String>{};

    try {
      addresses['ethereum'] = await getEthereumAddress();
    } catch (e) {
      addresses['ethereum'] = 'Error: $e';
    }

    try {
      addresses['solana'] = await getSolanaAddress();
    } catch (e) {
      addresses['solana'] = 'Error: $e';
    }

    return addresses;
  }

  /// Clears all cached data
  void clearCache() {
    _ethereumAddress = null;
    _solanaAddress = null;
    _ethCreds = null;
    _solanaPrivateKey32 = null;
  }
}
