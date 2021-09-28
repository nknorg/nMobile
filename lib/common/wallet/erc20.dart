import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math'; // used for the random number generator
import 'dart:typed_data';

import 'package:http/http.dart'; // You can also import the browser version
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class WalletEth with Tag {
  final String name;
  final Wallet raw;

  WalletEth(this.name, this.raw);

  Future<EthereumAddress> get address => credt.extractAddress();

  Credentials get credt => raw.privateKey;

  Uint8List get pubKeyBytes => privateKeyBytesToPublic(privateKeyBytes);
  String get pubKeyHex => hexEncode(pubKeyBytes);
  BigInt get pubKeyInt => bytesToInt(pubKeyBytes);

  Uint8List get privateKeyBytes => raw.privateKey.privateKey;
  String get privateKeyHex => hexEncode(privateKeyBytes);
  BigInt get privateKeyInt => bytesToInt(privateKeyBytes);

  // String get keystore => raw.toJson();

  Future<String> keystore() async {
    ReceivePort receivePort = ReceivePort();

    await Isolate.spawn(_loadKeystore, receivePort.sendPort);

    // The 'echo' isolate sends its SendPort as the first message
    SendPort sendPort = await receivePort.first;

    // send message to isolate thread
    ReceivePort response = ReceivePort();
    sendPort.send([response.sendPort, raw]);

    // get result from UI thread port
    String? result = await response.first;
    return result ?? "";
  }
}

_loadKeystore(SendPort sendPort) async {
  // Open the ReceivePort for incoming messages.
  ReceivePort port = ReceivePort();
  // Notify any other isolates what port this isolate listens to.
  sendPort.send(port.sendPort);

  // get response
  var msg = (await port.first) as List;
  SendPort replyTo = msg[0];
  Wallet wallet = msg[1];

  // get keystore
  String keystore = wallet.toJson();
  replyTo.send(keystore);

  // close
  port.close();
}

class Ethereum {
  static WalletEth create({required String name, required String password}) {
    final credentials = EthPrivateKey.createRandom(Random.secure());
    final raw = Wallet.createNew(credentials, password, Random.secure());
    return WalletEth(name, raw);
  }

  static Future<WalletEth> restoreByKeyStore({required String name, required String keystore, required String password}) async {
    try {
      ReceivePort receivePort = ReceivePort();

      await Isolate.spawn(_loadRestoreByKeyStore, receivePort.sendPort);

      // The 'echo' isolate sends its SendPort as the first message
      SendPort sendPort = await receivePort.first;

      // send message to isolate thread
      ReceivePort response = ReceivePort();
      sendPort.send([response.sendPort, name, keystore, password]);

      // final ethWallet = WalletEth(name, wallet);

      // get result from UI thread port
      List result = await response.first;
      if (result[1] != null) {
        throw result[1];
      }
      return result[0];
    } catch (e) {
      throw e;
    }
  }

  static WalletEth restoreByPrivateKey({required String name, required String privateKey, required String password}) {
    final credentials = EthPrivateKey.fromHex(privateKey);
    final raw = Wallet.createNew(credentials, password, Random.secure());
    return WalletEth(name, raw);
  }

  static bool isKeystoreValid(String jsonStr) {
    final data = jsonDecode(jsonStr);
    // Ensure version is 3, only version that we support at the moment
    final version = data['version'];
    if (version != 3) {
      return false;
    }
    final crypto = data['crypto'] ?? data['Crypto'];
    final kdf = crypto['kdf'] as String;
    return (kdf == 'pbkdf2' && crypto['kdfparams'] is Map) || (kdf == 'scrypt' && crypto['kdfparams'] is Map);
  }

  static EtherAmount etherToWei(num amount) {
    final amoStr = amount.toString();
    final dot = amoStr.lastIndexOf('.');
    if (dot < 0) {
      return EtherAmount.fromUnitAndValue(EtherUnit.ether, amount as int);
    } else {
      final int len = amoStr.length - dot - 1;
      final intPart = dot == 0 ? BigInt.from(0) : BigInt.parse(amoStr.substring(0, dot));
      final floatPart = BigInt.parse(amoStr.substring(dot + 1));
      return EtherAmount.inWei((BigInt.from(10).pow(18) * intPart) + ((BigInt.from(10).pow(18) * floatPart) ~/ BigInt.from(10).pow(len)));
    }
  }
}

_loadRestoreByKeyStore(SendPort sendPort) async {
  // Open the ReceivePort for incoming messages.
  ReceivePort port = ReceivePort();
  // Notify any other isolates what port this isolate listens to.
  sendPort.send(port.sendPort);

  // get response
  var msg = (await port.first) as List;
  SendPort replyTo = msg[0];
  String name = msg[1];
  String keystore = msg[2];
  String password = msg[3];

  // get wallet
  try {
    Wallet wallet = Wallet.fromJson(keystore, password);
    final ethWallet = WalletEth(name, wallet);
    replyTo.send([ethWallet, null]);
  } catch (e) {
    replyTo.send([null, e.toString()]);
  }

  // close
  port.close();
}

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

class EthErc20Client with Tag {
  // https://etherscan.io/apis
  // Note: Starting from February 15th, 2020, all developers are required to use a valid API key to access
  // the API services provided by Etherscan.
  // The Etherscan Ethereum Developer APIs are provided as a community service and without warranty, so
  // please just use what you need and no more. We support both GET/POST requests and there is a rate limit
  // of 5 calls per sec/IP.
  //
  // https://infura.io/dashboard/ethereum/3fc946dd60524031a13ab94738cfa6ce/settings
  static const RPC_SERVER_URL = 'https://mainnet.infura.io/v3/a7cc9467bd2644609b12cbc3625329c8';
  static const RPC_SERVER_URL_test = 'https://ropsten.infura.io/v3/a7cc9467bd2644609b12cbc3625329c8';

  // ignore: non_constant_identifier_names
  // StreamSubscription<FilterEvent>? _subscription;
  late Web3Client _web3client;

  EthErc20Client() {
    create();
  }

  Web3Client get client => _web3client;

  Future<EtherAmount> get getGasPrice => _web3client.getGasPrice();

  void create() {
    var httpClient = Client();
    _web3client = Web3Client(RPC_SERVER_URL, httpClient);
  }

  Future<EtherAmount?> getBalanceEth({required String address}) async {
    // var credentials = _web3client.credentialsFromPrivateKey("0x...");
    try {
      return await _web3client.getBalance(EthereumAddress.fromHex(address));
    } catch (e) {
      if (e.toString().contains("Connection terminated")) {
        create();
        await Future.delayed(Duration(seconds: 1));
        return getBalanceEth(address: address);
      }
      handleError(e);
      return null;
    }
  }

  Future<EtherAmount?> getBalanceNkn({required String address}) async {
    try {
      final balance = await _web3client.call(
        contract: Erc20Nkn.contract,
        function: Erc20Nkn.balanceOf,
        params: [EthereumAddress.fromHex(address)],
      );
      return EtherAmount.inWei(balance.first);
    } catch (e) {
      if (e.toString().contains("Connection terminated")) {
        create();
        await Future.delayed(Duration(seconds: 1));
        return getBalanceNkn(address: address);
      }
      handleError(e);
      return null;
    }
  }

  /// Returns a hash of the transaction.
  /// [gasLimit] default `90000`. https://github.com/ethereum/wiki/wiki/JSON-RPC#parameters-22.
  Future<String> sendEthereum(
    Credentials credt, {
    required String address,
    required num amountEth,
    required int gasLimit,
    int? gasPriceInGwei,
  }) async {
    try {
      return _web3client.sendTransaction(
        credt,
        Transaction(
          to: EthereumAddress.fromHex(address),
          maxGas: gasLimit,
          gasPrice: gasPriceInGwei == null ? null : EtherAmount.fromUnitAndValue(EtherUnit.gwei, gasPriceInGwei),
          value: amountEth.ETH,
        ),
        chainId: null,
        fetchChainIdFromNetworkId: true,
      );
    } catch (e) {
      if (e.toString().contains("Connection terminated")) {
        create();
        await Future.delayed(Duration(seconds: 1));
        return sendEthereum(credt, address: address, amountEth: amountEth, gasLimit: gasLimit, gasPriceInGwei: gasPriceInGwei);
      }
      handleError(e);
      rethrow;
    }
  }

  Future<String> sendNknToken(
    Credentials credt, {
    required String address,
    required num amountNkn,
    required int gasLimit,
    int? gasPriceInGwei,
  }) async {
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
        chainId: null,
        fetchChainIdFromNetworkId: true,
      );
    } catch (e) {
      if (e.toString().contains("Connection terminated")) {
        create();
        await Future.delayed(Duration(seconds: 1));
        return sendNknToken(credt, address: address, amountNkn: amountNkn, gasLimit: gasLimit, gasPriceInGwei: gasPriceInGwei);
      }
      handleError(e);
      rethrow;
    }
  }

  // void listenTokenEvent(void callback(EthereumAddress from, EthereumAddress to, EtherAmount balance)) {
  //   _subscription ??= _web3client
  //       .events(FilterOptions.events(
  //     contract: Erc20Nkn.contract,
  //     event: Erc20Nkn.transferEvent,
  //   ))
  //       .listen((event) {
  //     final decoded = Erc20Nkn.transferEvent.decodeResults(event.topics, event.data);
  //
  //     final from = decoded[0] as EthereumAddress;
  //     final to = decoded[1] as EthereumAddress;
  //     final value = decoded[2] as BigInt;
  //     final balance = EtherAmount.inWei(value);
  //     // _LOG.i('onTokenEvent: $from sent ${balance.getValueInUnit(EtherUnit.ether)} NKN to $to');
  //
  //     callback(from, to, balance);
  //   });
  // }

  Future<void> close() {
    // _subscription?.cancel();
    return _web3client.dispose();
  }
}

extension EtherAmountNum on num {
  // ignore: non_constant_identifier_names
  EtherAmount get ETH => Ethereum.etherToWei(this);

  // ignore: non_constant_identifier_names
  EtherAmount get NKN => Ethereum.etherToWei(this);
}

extension EtherAmountInt on int {
  EtherAmount get gwei => EtherAmount.fromUnitAndValue(EtherUnit.gwei, this);
}

extension DoubleEtherAmount on EtherAmount {
  num get ether => this.getValueInUnit(EtherUnit.ether);

  num get gwei => this.getValueInUnit(EtherUnit.gwei);
}
