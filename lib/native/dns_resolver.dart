import 'package:flutter/services.dart';

class DnsResolverConfig {
  final String? dnsServer;

  DnsResolverConfig({this.dnsServer});
}

class DnsResolver {
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.mobile/native/nameservice/dnsresolver');

  static install() {}

  static Future<String> resolve(DnsResolverConfig config, String address) async {
    try {
      return await _methodChannel.invokeMethod('resolve', {
        'config': {
          'dnsServer': config.dnsServer,
        },
        'address': address,
      });
    } catch (e) {
      throw e;
    }
  }
}
