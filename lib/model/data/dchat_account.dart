import 'dart:typed_data';

import 'package:nmobile/helpers/sqlite_storage.dart';
import 'package:nmobile/plugins/nkn_client.dart';

class DChatAccount {
  final Wallet wallet;
  final NknClientProxy client;
  SqliteStorage _dbStore;

  DChatAccount(String walletAddress, String pubkey, Uint8List seed, ClientEventDispatcher clientEvent)
      : wallet = Wallet(walletAddress, pubkey),
        client = NknClientProxy(seed, pubkey, clientEvent);

  SqliteStorage get dbHolder {
    _dbStore ??= SqliteStorage(client.pubkey, client.dbCipherPassphrase);
    return _dbStore;
  }
}

class Wallet {
  final String address;
  final String pubkey;

  const Wallet(this.address, this.pubkey)
      : assert(address != null),
        assert(pubkey != null);
}
