/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:math'; //used for the random number generator
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart'; //You can also import the browser version
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// @author Chenai
/// @version 1.0, 20/07/2020
class Erc20Nkn {
  static const SMART_CONTRACT_ADDRESS = '0x5cf04716ba20127f1e2297addcf4b5035000c9eb';
  static const SMART_CONTRACT_NAME = 'NKNToken';
  static const ABI_CODE =
      '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"transferable","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_transferable","type":"bool"}],"name":"setTransferable","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupplyCap","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_owner","type":"address"}],"name":"transferOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"inputs":[{"name":"_issuer","type":"address"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"owner","type":"address"},{"indexed":true,"name":"spender","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Approval","type":"event"}]';

  static DeployedContract get contract => DeployedContract(
        ContractAbi.fromJson(ABI_CODE, SMART_CONTRACT_NAME),
        EthereumAddress.fromHex(SMART_CONTRACT_ADDRESS),
      );

  static final balanceOf = contract.function('balanceOf');
  static final transferFunc = contract.function('transfer');
  static final transferEvent = contract.event('Transfer');
}

class EthWallet {
  final String name;
  final Wallet raw;

  const EthWallet(this.name, this.raw);

  Future<EthereumAddress> get address => Ethereum.deriveAddressByCredt(credt);

  Credentials get credt => raw.privateKey;

  @Deprecated('Be careful, not needed in general.')
  Uint8List get privateKeyBytes => raw.privateKey.privateKey;

  Uint8List get pubkey => privateKeyBytesToPublic(privateKeyBytes);

  BigInt get pubkeyInt => bytesToInt(privateKeyBytesToPublic(raw.privateKey.privateKey));

  String get keystore => raw.toJson();
}

class EthErc20Client with Tag {
  // https://etherscan.io/apis
  // Note: Starting from February 15th, 2020, all developers are required to use a valid API key to access
  // the API services provided by Etherscan.
  // The Etherscan Ethereum Developer APIs are provided as a community service and without warranty, so
  // please just use what you need and no more. We support both GET/POST requests and there is a rate limit
  // of 5 calls per sec/IP.
  //
  // https://infura.io/dashboard/ethereum/3fc946dd60524031a13ab94738cfa6ce/settings
  static const RPC_SERVER_URL = 'https://mainnet.infura.io/v3/3fc946dd60524031a13ab94738cfa6ce';
  static const RPC_SERVER_URL_test = 'https://ropsten.infura.io/v3/3fc946dd60524031a13ab94738cfa6ce';

  static const address = '0x32a37d137A3a92900fB4f45C1Bc3713A9D81e407';

  // ignore: non_constant_identifier_names
  LOG _LOG;
  Web3Client _web3client;
  StreamSubscription<FilterEvent> _subscription;

  EthErc20Client() {
    _LOG = LOG(tag);
    var httpClient = Client();
    _web3client = Web3Client(RPC_SERVER_URL, httpClient);
  }

  Web3Client get client => _web3client;

  Future<EtherAmount> getBalance({@required String address}) {
    // var credentials = _web3client.credentialsFromPrivateKey("0x...");
    return _web3client.getBalance(EthereumAddress.fromHex(address));
  }

  Future<EtherAmount> getNknBalance({@required String address}) async {
    final balance = await _web3client.call(
      contract: Erc20Nkn.contract,
      function: Erc20Nkn.balanceOf,
      params: [EthereumAddress.fromHex(address)],
    );
    return EtherAmount.inWei(balance.first);
  }

  /// Returns a hash of the transaction.
  /// [gasLimit] default `90000`. https://github.com/ethereum/wiki/wiki/JSON-RPC#parameters-22.
  Future<String> sendEthereum(
    Credentials credt, {
    @required String address,
    @required num amountEth,
    @required int gasLimit,
    int gasPriceInGwei,
  }) {
    _LOG.d('sendEthereum(credt:$credt, address:$address, amountEth:$amountEth, gasLimit:$gasLimit, gasPriceInGwei:$gasPriceInGwei)');
    try {
      return _web3client.sendTransaction(
          credt,
          Transaction(
            to: EthereumAddress.fromHex(address),
            maxGas: gasLimit,
            gasPrice: gasPriceInGwei == null ? null : EtherAmount.fromUnitAndValue(EtherUnit.gwei, gasPriceInGwei),
            value: amountEth.ETH,
          ),
          fetchChainIdFromNetworkId: true);
    } catch (e) {
      _LOG.e('sendEthereum:', e);
      rethrow;
    }
  }

  Future<String> sendNknToken(
    Credentials credt, {
    @required String address,
    @required num amountNkn,
    @required int gasLimit,
    int gasPriceInGwei,
  }) async {
    _LOG.d('sendNknToken(credt:$credt, address:$address, amountNkn:$amountNkn, gasLimit:$gasLimit, gasPriceInGwei:$gasPriceInGwei)');
    try {
      return _web3client.sendTransaction(
          credt,
          Transaction.callContract(
            contract: Erc20Nkn.contract,
            function: Erc20Nkn.transferFunc,
            parameters: [
              // {"name":"_to","type":"address"},{"name":"_value","type":"uint256"}
              EthereumAddress.fromHex(address), // _to
              amountNkn.NKN.getInWei // _value: BigInt.
            ],
            maxGas: gasLimit,
            gasPrice: gasPriceInGwei == null ? null : EtherAmount.fromUnitAndValue(EtherUnit.gwei, gasPriceInGwei),
          ),
          fetchChainIdFromNetworkId: true);
    } catch (e) {
      _LOG.e('sendNknToken:', e);
      rethrow;
    }
  }

  void listenTokenEvent(void callback(EthereumAddress from, EthereumAddress to, EtherAmount balance)) {
    _subscription ??= _web3client
        .events(FilterOptions.events(
      contract: Erc20Nkn.contract,
      event: Erc20Nkn.transferEvent,
    ))
        .listen((event) {
      final decoded = Erc20Nkn.transferEvent.decodeResults(event.topics, event.data);

      final from = decoded[0] as EthereumAddress;
      final to = decoded[1] as EthereumAddress;
      final value = decoded[2] as BigInt;
      final balance = EtherAmount.inWei(value);
      _LOG.i('onTokenEvent: $from sent ${balance.getValueInUnit(EtherUnit.ether)} NKN to $to');

      callback(from, to, balance);
    });
  }

  Future<void> close() {
    _subscription?.cancel();
    return _web3client.dispose();
  }
}

class Ethereum {
  // ignore: non_constant_identifier_names
  static LOG _LOG = LOG('Ethereum');

  static EthWallet createWallet({@required String name, @required String password}) {
    final credentials = EthPrivateKey.createRandom(Random.secure());
    final raw = Wallet.createNew(credentials, password, Random.secure());
    return EthWallet(name, raw);
  }

  static EthWallet restoreWallet({@required String name, @required String keystore, @required String password}) {
    try {
      return EthWallet(name, verifyPassword(keystore: keystore, password: password));
    } catch (e) {
      throw e;
    }
  }

  static Future<EthWallet> restoreWalletSaved({@required WalletSchema schema, @required String password}) async {
    return restoreWallet(name: schema.name, keystore: await schema.getKeystore(), password: password);
  }

  static void saveWallet({@required EthWallet ethWallet, @required WalletsBloc walletsBloc}) async {
    final schema = WalletSchema(address: (await ethWallet.address).hex, name: ethWallet.name, type: WalletSchema.ETH_WALLET);
    walletsBloc.add(AddWallet(schema, ethWallet.keystore));
  }

  static Wallet verifyPassword({@required String keystore, @required String password}) {
    try {
      return Wallet.fromJson(keystore, password);
    } catch (e) {
      _LOG.e('verifyPassword', e);
      throw e;
    }
  }

  static Credentials walletFromPrivateKey({@required String privateKey}) {
    return EthPrivateKey.fromHex(privateKey);
  }

  static Future<EthereumAddress> deriveAddressByWallet(EthWallet ethWallet) {
    return deriveAddressByCredt(ethWallet.credt);
  }

  static Future<EthereumAddress> deriveAddressByCredt(Credentials credentials) async {
    final address = await credentials.extractAddress();
    _LOG.i(address.hex);
    return address;
  }

  static EtherAmount etherToWei(num amount) {
    final amoStr = amount.toString();
    final dot = amoStr.lastIndexOf('.');
    if (dot < 0) {
      return EtherAmount.fromUnitAndValue(EtherUnit.ether, amount as int);
    } else {
      final int len = amoStr.length - dot - 1;
      final toBigInt = BigInt.parse(amoStr.substring(dot + 1));
      return EtherAmount.inWei((BigInt.from(10).pow(18) * toBigInt) ~/ BigInt.from(10).pow(len));
    }
  }
}

extension EtherAmountNum on num {
  // ignore: non_constant_identifier_names
  EtherAmount get ETH => Ethereum.etherToWei(this);

  // ignore: non_constant_identifier_names
  EtherAmount get NKN => Ethereum.etherToWei(this);
}
