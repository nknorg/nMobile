import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

import '../../helpers/error.dart';

class NKNAccount {
  static const SMART_CONTRACT_ADDRESS = '0xf6Af6126D18FD3d64A771E5F449c706bb4121953';
  static const SMART_CONTRACT_NAME = 'NKNAccount';
  static const ABI_CODE =
      '[{ "inputs": [], "name": "del", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [ { "internalType": "address", "name": "publicKey", "type": "address" } ], "name": "getNKNAddr", "outputs": [ { "components": [ { "internalType": "string", "name": "identifier", "type": "string" }, { "internalType": "bytes32", "name": "publicKey", "type": "bytes32" } ], "internalType": "struct NKNAccount.NKNAddress", "name": "", "type": "tuple" } ], "stateMutability": "view", "type": "function" }, { "inputs": [], "name": "getNKNAddr", "outputs": [ { "components": [ { "internalType": "string", "name": "identifier", "type": "string" }, { "internalType": "bytes32", "name": "publicKey", "type": "bytes32" } ], "internalType": "struct NKNAccount.NKNAddress", "name": "", "type": "tuple" } ], "stateMutability": "view", "type": "function" }, { "inputs": [ { "internalType": "string", "name": "identifier", "type": "string" }, { "internalType": "bytes32", "name": "publicKey", "type": "bytes32" } ], "name": "set", "outputs": [], "stateMutability": "nonpayable", "type": "function" }]';

  static DeployedContract get contract => DeployedContract(
        ContractAbi.fromJson(ABI_CODE, SMART_CONTRACT_NAME),
        EthereumAddress.fromHex(SMART_CONTRACT_ADDRESS),
      );

  static final set = contract.function('set');
  static final del = contract.function('del');
  static final getNKNAddr = contract.functions.firstWhere((e) => e.name == 'getNKNAddr' && e.parameters.length > 0);
}

class NKNAccountContract {
  static const RPC_SERVER_URL = 'https://mainnet.infura.io/v3/a7cc9467bd2644609b12cbc3625329c8';
  static const RPC_SERVER_URL_test = 'https://rinkeby.infura.io/v3/a7cc9467bd2644609b12cbc3625329c8';

  late Web3Client _web3client;

  NKNAccountContract() {
    _web3client = Web3Client(RPC_SERVER_URL_test, Client());
  }

  Web3Client get client => _web3client;

  Future<EtherAmount> get getGasPrice => _web3client.getGasPrice();

  Future<String?> getNKNAddr(String address) async {
    try {
      final result = await _web3client.call(
        contract: NKNAccount.contract,
        function: NKNAccount.getNKNAddr,
        params: [EthereumAddress.fromHex(address)],
      );
      String identifier = result.first[0];
      String pubkey = hexEncode(result.first[1]);
      String addr = pubkey;
      if (identifier.isNotEmpty) {
        addr = '$identifier.$pubkey';
      }
      return addr;
    } catch (e) {
      handleError(e);
    }
  }

  Future<void> close() {
    return _web3client.dispose();
  }
}
