// import 'package:flutter/services.dart';

class EthResolverConfig {
  final String? prefix;
  final String? rpcServer;
  final String? contractAddress;

  EthResolverConfig({this.prefix, this.rpcServer, this.contractAddress});
}

// class EthResolver {
//   static const MethodChannel _methodChannel = MethodChannel('org.nkn.mobile/native/nameservice/ethresolver');
//
//   static install() {}
//
//   static Future<String> resolve(EthResolverConfig config, String address) async {
//     try {
//       return await _methodChannel.invokeMethod('resolve', {
//         'config': {
//           'prefix': config.prefix,
//           'contractAddress': config.contractAddress,
//           'rpcServer': config.rpcServer,
//         },
//         'address': address,
//       });
//     } catch (e) {
//       throw e;
//     }
//   }
// }
