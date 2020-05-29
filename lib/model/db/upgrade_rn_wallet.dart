import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class UpgradeRnWallet {
  static const String _TABLE_NAME = "catalystLocalStorage";
  static const String _COLUMN_KEY = "key";
  static const String _COLUMN_VALUE = "value";
  static const String _COLUMN_KEY_LEN = 'wallets:length';
  static const String _WALLETS_i = 'wallets:';

  static Future<Database> _openRnWalletDb() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'RKStorage');
    var exists = await databaseExists(path);
    if (exists) {
      return await openDatabase(path, readOnly: true);
    } else {
      return null;
    }
  }

  static Future<List<RnWalletData>> get rnWalletList async {
    var db = await _openRnWalletDb();
    print('UpgradeRnWallet | rnWalletList: $db');
    if (db == null) {
      return null;
    } else {
      var list = await db.query(_TABLE_NAME,
          distinct: true,
          columns: [_COLUMN_KEY, _COLUMN_VALUE],
          where: "$_COLUMN_KEY = ?",
          whereArgs: [_COLUMN_KEY_LEN]);
      print('UpgradeRnWallet | rnWalletList: $list');
      if (list.length > 0) {
        // [{key: wallets:length, value: 2}]
        List<RnWalletData> result = <RnWalletData>[];
        final length = int.parse(list[0][_COLUMN_VALUE]);
        int i = 0;
        while (i < length) {
          final dataLi = await db.query(_TABLE_NAME,
              distinct: true,
              columns: [_COLUMN_KEY, _COLUMN_VALUE],
              where: "$_COLUMN_KEY = ?",
              whereArgs: ["$_WALLETS_i$i"]);
          final keystore = dataLi[0][_COLUMN_VALUE];
          print("rnWalletList | query db wallet: $keystore");
          try {
            final walletDataMap = jsonDecode(keystore);
            print("rnWalletList | jsonDecode walletDataMap: $walletDataMap");
            final data = RnWalletData();
            data.type = walletDataMap['type'];
            data.address = walletDataMap['address'];
            data.publicKey = walletDataMap['publicKey'];
            data.keystore = jsonEncode(walletDataMap['keystore']);
            data.name = walletDataMap['name'];
            data.balance = walletDataMap['balance'];
            data.tokenBalance = walletDataMap['tokenBalance'];
            print("rnWalletList | jsonDecode RnWalletData.keystore: ${data.keystore}");

            result.add(data);
          } on Exception catch (e) {
            print(e);
          }
          ++i;
        }
        db.close();
        return result;
      } else {
        return null;
      }
    }
  }
}

class RnWalletData {
  String type;
  String address;
  String publicKey;
  String keystore;
  String name;
  String balance;
  String tokenBalance;

  bool get isEth => type == typeEth;

  static const typeNkn = "NKN_WALLET";
  static const typeEth = "ETH_WALLET";
}
