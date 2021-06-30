import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class WalletConfig {
  final String? password;
  final List<String>? seedRPCServerAddr;

  WalletConfig({this.password, this.seedRPCServerAddr});
}

class RpcConfig {
  final List<String>? seedRPCServerAddr;

  RpcConfig({this.seedRPCServerAddr});
}

class Wallet {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/wallet');

  static install() {}

  late String address;
  late Uint8List seed;
  late Uint8List publicKey;
  late String keystore;

  WalletConfig walletConfig;

  Wallet({required this.walletConfig});

  static Future<Wallet> create(Uint8List? seed, {required WalletConfig config}) async {
    try {
      final Map data = await _methodChannel.invokeMethod('create', {
        'seed': seed,
        'password': config.password,
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

  static Future<Wallet> restore(String keystore, {required WalletConfig config}) async {
    try {
      final Map data = await _methodChannel.invokeMethod('restore', {
        'keystore': keystore,
        'password': config.password,
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

  static Future<double> getBalanceByAddr(String address, {WalletConfig? config}) async {
    try {
      return await _methodChannel.invokeMethod('getBalance', {
        'address': address,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true ? config?.seedRPCServerAddr : null,
      });
    } catch (e) {
      throw e;
    }
  }

  Future<double> getBalance() async {
    return getBalanceByAddr(this.address, config: this.walletConfig);
  }

  Future<String?> transfer(String address, String amount, {String fee = '0', int? nonce, Uint8List? attributes}) async {
    try {
      return await _methodChannel.invokeMethod('transfer', {
        'seed': this.seed,
        'address': address,
        'amount': amount,
        'fee': fee,
        'nonce': nonce,
        'attributes': attributes,
        'seedRpc': this.walletConfig.seedRPCServerAddr,
      });
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pubKeyToWalletAddr(String publicKey) async {
    try {
      final String address = await _methodChannel.invokeMethod('pubKeyToWalletAddr', {
        'publicKey': publicKey,
      });
      return address;
    } catch (e) {
      return null;
    }
  }

  static Future<int> getSubscribersCount(String topic, Uint8List subscriberHashPrefix, {RpcConfig? config}) async {
    try {
      int count = await _methodChannel.invokeMethod('getSubscribersCount', {
        'topic': topic,
        'subscriberHashPrefix': subscriberHashPrefix,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true ? config?.seedRPCServerAddr : null,
      });
      return count;
    } catch (e) {
      throw e;
    }
  }

  static Future<Map<String, dynamic>?> getSubscription(String topic, String subscriber, {RpcConfig? config}) async {
    try {
      Map? resp = await _methodChannel.invokeMethod('getSubscription', {
        'topic': topic,
        'subscriber': subscriber,
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true ? config?.seedRPCServerAddr : null,
      });
      if (resp == null) {
        return null;
      }
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      throw e;
    }
  }

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
        'seedRpc': config?.seedRPCServerAddr?.isNotEmpty == true ? config?.seedRPCServerAddr : null,
      });
      if (resp == null) {
        return null;
      }
      return Map<String, dynamic>.from(resp);
    } catch (e) {
      throw e;
    }
  }
}
