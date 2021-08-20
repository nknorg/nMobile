import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

const String DEFAULT_SEED_RPC_SERVER = 'http://seed.nkn.org:30003';

/// Wallet config
class WalletConfig {
  final String? password;
  final List<String>? seedRPCServerAddr;

  WalletConfig({this.password, this.seedRPCServerAddr});
}

/// RPC config
class RpcConfig {
  final List<String>? seedRPCServerAddr;

  RpcConfig({this.seedRPCServerAddr = const [DEFAULT_SEED_RPC_SERVER]});
}

/// Wallet manages assets, query state from blockchain, and send transactions to
/// blockchain.
class Wallet {
  static const MethodChannel _methodChannel =
      MethodChannel('org.nkn.sdk/wallet');

  /// Need to [install] before use.
  static install() {}

  /// NKN wallet address
  late String address;

  /// NKN wallet seed
  late Uint8List seed;

  /// NKN wallet public key
  late Uint8List publicKey;

  /// NKN wallet keystore
  late String keystore;

  WalletConfig walletConfig;

  Wallet({required this.walletConfig});

  /// [measureSeedRPCServer] measures the latency to seed rpc node list, only
  /// select the ones in persist finished state, and sort them by latency (from low
  /// to high). If none of the given seed rpc node is accessable or in persist
  /// finished state, returned string array will contain zero elements. Timeout is
  /// in millisecond.
  static Future<List<String>?> measureSeedRPCServer(
      List<String> seedRPCServerAddr) async {
    try {
      final Map data =
          await _methodChannel.invokeMethod('measureSeedRPCServer', {
        'seedRpc': seedRPCServerAddr.isNotEmpty == true
            ? seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
      List<String> result = [];
      (data['seedRPCServerAddrList'] as List?)?.forEach((element) {
        if (element is String && element.isNotEmpty) {
          result.add(element);
        }
      });
      return result;
    } catch (e) {
      throw e;
    }
  }

  /// [create] creates a wallet from an account and an optional config. For any
  /// zero value field in config, the default wallet config value will be used. If
  /// config is nil, the default wallet config will be used. However, it is
  /// strongly recommended to use non-empty password in config to protect the
  /// wallet, otherwise anyone can recover the wallet and control all assets in the
  /// wallet from the generated wallet JSON.
  static Future<Wallet> create(Uint8List? seed,
      {required WalletConfig config}) async {
    try {
      final Map data = await _methodChannel.invokeMethod('create', {
        'seed': seed,
        'password': config.password,
        'seedRpc': config.seedRPCServerAddr?.isNotEmpty == true
            ? config.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
      Wallet wallet = Wallet(walletConfig: config);
      wallet.keystore = data['keystore'];
      wallet.address = data['address'];
      wallet.seed = data['seed'];
      wallet.publicKey = data['publicKey'];
      return wallet;
    } catch (e) {
      throw e;
    }
  }

  /// [restore] recovers a wallet from wallet JSON and wallet config. The
  /// password in config must match the password used to create the wallet
  static Future<Wallet> restore(String keystore,
      {required WalletConfig config}) async {
    try {
      final Map data = await _methodChannel.invokeMethod('restore', {
        'keystore': keystore,
        'password': config.password,
        'seedRpc': config.seedRPCServerAddr?.isNotEmpty == true
            ? config.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
      Wallet wallet = Wallet(walletConfig: config);
      wallet.keystore = data['keystore'];
      wallet.address = data['address'];
      wallet.seed = data['seed'];
      wallet.publicKey = data['publicKey'];
      return wallet;
    } catch (e) {
      throw e;
    }
  }

  /// [getBalanceByAddr] is the same as [getBalance]
  static Future<double> getBalanceByAddr(String address,
      {WalletConfig? config}) async {
    try {
      return await _methodChannel.invokeMethod('getBalance', {
        'address': address,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
    } catch (e) {
      throw e;
    }
  }

  /// [getBalance] RPC returns the balance of a wallet address
  Future<double> getBalance() async {
    return getBalanceByAddr(this.address, config: this.walletConfig);
  }

  /// [transfer] sends asset to a wallet address with a transaction fee.
  /// Amount is the string representation of the amount in unit of NKN to avoid
  /// precision loss. For example, "0.1" will be parsed as 0.1 NKN. The
  /// signerRPCClient can be a client, multiclient or wallet.
  Future<String?> transfer(String address, String amount,
      {String fee = '0', int? nonce, Uint8List? attributes}) async {
    try {
      return await _methodChannel.invokeMethod('transfer', {
        'seed': this.seed,
        'address': address,
        'amount': amount,
        'fee': fee,
        'nonce': nonce,
        'attributes': attributes,
        'seedRpc':
            this.walletConfig.seedRPCServerAddr ?? [DEFAULT_SEED_RPC_SERVER],
      });
    } catch (e) {
      throw e;
    }
  }

  /// [pubKeyToWalletAddr] converts a public key to its NKN wallet address
  static Future<String?> pubKeyToWalletAddr(String publicKey) async {
    try {
      final String address =
          await _methodChannel.invokeMethod('pubKeyToWalletAddr', {
        'publicKey': publicKey,
      });
      return address;
    } catch (e) {
      return null;
    }
  }

  /// [getSubscribersCount] RPC returns the number of subscribers of a topic
  /// (not including txPool). If [subscriberHashPrefix] is not empty, only subscriber
  /// whose sha256(pubkey+identifier) contains this prefix will be counted. Each
  /// prefix byte will reduce result count to about 1/256, and also reduce response
  /// time to about 1/256 if there are a lot of subscribers. This is a good way to
  /// sample subscribers randomly with low cost.
  static Future<int> getSubscribersCount(
      String topic, Uint8List subscriberHashPrefix,
      {RpcConfig? config}) async {
    try {
      int count = await _methodChannel.invokeMethod('getSubscribersCount', {
        'topic': topic,
        'subscriberHashPrefix': subscriberHashPrefix,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
      return count;
    } catch (e) {
      throw e;
    }
  }

  /// [getSubscription] RPC gets the subscription details of a subscriber in a topic.
  static Future<Map<String, dynamic>?> getSubscription(
      String topic, String subscriber,
      {RpcConfig? config}) async {
    try {
      Map? resp = await _methodChannel.invokeMethod('getSubscription', {
        'topic': topic,
        'subscriber': subscriber,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
      if (resp == null) {
        return null;
      }
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      throw e;
    }
  }

  /// [getSubscribers] RPC returns the number of subscribers of a topic
  /// (not including txPool). If [subscriberHashPrefix] is not empty, only subscriber
  /// whose sha256(pubkey+identifier) contains this prefix will be counted. Each
  /// prefix byte will reduce result count to about 1/256, and also reduce response
  /// time to about 1/256 if there are a lot of subscribers. This is a good way to
  /// sample subscribers randomly with low cost.
  static Future<Map<String, dynamic>?> getSubscribers({
    required String topic,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
    Uint8List? subscriberHashPrefix,
    RpcConfig? config,
  }) async {
    try {
      Map? resp = await _methodChannel.invokeMethod('getSubscribers', {
        'topic': topic,
        'offset': offset,
        'limit': limit,
        'meta': meta,
        'txPool': txPool,
        'subscriberHashPrefix': subscriberHashPrefix,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
      if (resp == null) {
        return null;
      }
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      throw e;
    }
  }

  /// [getHeight] RPC returns the latest block height.
  static Future<int?> getHeight({RpcConfig? config}) async {
    try {
      return await _methodChannel.invokeMethod('getHeight', {
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
    } catch (e) {
      throw e;
    }
  }

  /// [getNonce] RPC gets the next nonce to use of an address. If txPool is
  /// false, result only counts transactions in ledger; if txPool is true,
  /// transactions in txPool are also counted.
  Future<int?> getNonce({bool txPool = true}) async {
    try {
      return await _methodChannel.invokeMethod('getNonce', {
        'address': this.address,
        'txPool': txPool,
        'seedRpc':
            this.walletConfig.seedRPCServerAddr ?? [DEFAULT_SEED_RPC_SERVER],
      });
    } catch (e) {
      throw e;
    }
  }

  /// [getNonceByAddress] is the same as [getNonce]
  static Future<int?> getNonceByAddress(String address,
      {bool txPool = true, RpcConfig? config}) async {
    try {
      return await _methodChannel.invokeMethod('getNonce', {
        'address': address,
        'txPool': txPool,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true
            ? config?.seedRPCServerAddr
            : [DEFAULT_SEED_RPC_SERVER],
      });
    } catch (e) {
      throw e;
    }
  }
}
