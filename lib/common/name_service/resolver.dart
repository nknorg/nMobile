import 'package:nmobile/native/dns_resolver.dart' as native;
import 'package:nmobile/native/eth_resolver.dart' as native;

class Resolver {
  static native.EthResolverConfig ETH_RESOLVER_CONFIG = native.EthResolverConfig(
    contractAddress: '0x7BfFaF65698ecA3187CEE7651d0678127Bd7e1e2',
    rpcServer: 'https://mainnet.infura.io/v3/3398e48e733d4b9bb337702c05a77c2d',
    prefix: 'ETH:',
  );
  static native.EthResolverConfig HARMONY_RESOLVER_CONFIG = native.EthResolverConfig(
    contractAddress: '0x5969aC08B88819201A30CdBaA9D1c5a04Dc0C52d',
    rpcServer: 'https://api.harmony.one',
    prefix: 'ONE:',
  );
  static native.EthResolverConfig IOTEX_RESOLVER_CONFIG = native.EthResolverConfig(
    contractAddress: '0xFE9Ca78B57D72226266113660e92B111a5D2E316',
    rpcServer: 'https://babel-api.mainnet.iotex.io',
    prefix: 'IOTX:',
  );
  static native.EthResolverConfig THETA_RESOLVER_CONFIG = native.EthResolverConfig(
    contractAddress: '0x748f7CeF212ce30e6Ce8c176D2b581a3E4EbD729',
    rpcServer: 'https://eth-rpc-api.thetatoken.org/rpc',
    prefix: 'TFUEL:',
  );

  static native.DnsResolverConfig DNS_RESOLVER_CONFIG = native.DnsResolverConfig(dnsServer: '8.8.8.8:53');

  Future<String?> resolve(String address) async {
    String addr = address;
    for (int i = 0; i < 16; i++) {
      var config;
      if (addr.toUpperCase().startsWith('DNS:')) {
        config = DNS_RESOLVER_CONFIG;
        addr = await native.DnsResolver.resolve(config, addr);
      } else {
        if (addr.toUpperCase().startsWith(ETH_RESOLVER_CONFIG.prefix!)) {
          config = ETH_RESOLVER_CONFIG;
        } else if (addr.toUpperCase().startsWith(HARMONY_RESOLVER_CONFIG.prefix!)) {
          config = HARMONY_RESOLVER_CONFIG;
        } else if (addr.toUpperCase().startsWith(IOTEX_RESOLVER_CONFIG.prefix!)) {
          config = IOTEX_RESOLVER_CONFIG;
        } else if (addr.toUpperCase().startsWith(THETA_RESOLVER_CONFIG.prefix!)) {
          config = THETA_RESOLVER_CONFIG;
        }
        if (config == null) return null;
        addr = await native.EthResolver.resolve(config, addr);
      }

      if (addr.indexOf(':') == -1) {
        return addr;
      }
    }
    return addr;
  }
}
