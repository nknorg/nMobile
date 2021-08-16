import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';

import '../global.dart';

class WalletCommon with Tag {
  WalletStorage _walletStorage = WalletStorage();

  WalletCommon();

  Future<WalletSchema?> getInStorageByAddress(String? address) async {
    if (address == null || address.length == 0) return null;
    List<WalletSchema> wallets = await _walletStorage.getWallets();
    if (wallets.isEmpty) return null;
    try {
      return wallets.firstWhere((x) => x.address == address);
    } catch (e) {
      return null;
    }
  }

  WalletSchema? getInOriginalByAddress(List<WalletSchema>? wallets, String? address) {
    if (address == null || address.length == 0) return null;
    if (wallets == null || wallets.isEmpty) return null;
    try {
      return wallets.firstWhere((x) => x.address == address);
    } catch (e) {
      return null;
    }
  }

  Future<String> getKeystoreByAddress(String? address) async {
    String? keystore = await _walletStorage.getKeystore(address);
    if (keystore == null || keystore.isEmpty) {
      throw new Exception("keystore not exits");
    }
    return keystore;
  }

  Future getPassword(String walletAddress) {
    return _walletStorage.getPassword(walletAddress);
  }

  Future<bool> isBackup({List? original}) async {
    List wallets = original ?? await _walletStorage.getWallets();
    // backups
    List<Future> futures = <Future>[];
    wallets.forEach((value) {
      futures.add(_walletStorage.isBackupByAddress(value?.address));
    });
    List backups = await Future.wait(futures);
    // allBackup
    bool? find = backups.firstWhere((backup) => backup == null || backup == false, orElse: () => true);
    bool allBackup = (find != null && find == true) ? true : false;
    return allBackup;
  }

  Future<WalletSchema?> getDefault() async {
    String? address = await getDefaultAddress();
    WalletSchema? result = await getInStorageByAddress(address);
    if (result == null) {
      List<WalletSchema> wallets = await _walletStorage.getWallets();
      if (wallets.isNotEmpty) {
        address = wallets[0].address;
        await _walletStorage.setDefaultAddress(address);
        result = await getInStorageByAddress(address);
      }
    }
    return result;
  }

  Future<String?> getDefaultAddress() {
    return _walletStorage.getDefaultAddress();
  }

  bool isBalanceSame(WalletSchema? w1, WalletSchema? w2) {
    if (w1 == null || w2 == null) return true;
    return w1.balance == w2.balance && w1.balanceEth == w2.balanceEth;
  }

  queryBalance() {
    WalletBloc _walletBloc = BlocProvider.of<WalletBloc>(Global.appContext);
    var state = _walletBloc.state;
    if (state is WalletLoaded) {
      logger.d("$TAG - queryBalance: START");
      List<Future> futures = <Future>[];
      state.wallets.forEach((w) async {
        if (w.type == WalletType.eth) {
          // TODO:GG eth balance query
          // EthErc20Client _erc20client = EthErc20Client();
          // futures.add(_erc20client.getBalance(address: w.address).then((balance) {
          //   NLog.w('Get Wallet:${w.name} | balance: ${balance.ether}');
          //   w.balanceEth = balance.ether;
          //   _walletsBloc.add(UpdateWallet(w));
          // }));
          // futures.add(
          //     _erc20client.getNknBalance(address: w.address).then((balance) {
          //       if (balance != null) {
          //         NLog.w('Get Wallet:${w.name} | balance: ${balance.ether}');
          //         w.balance = balance.ether;
          //         _walletsBloc.add(UpdateWallet(w));
          //       }
          //     }));
        } else {
          Wallet.getBalanceByAddr(w.address, config: WalletConfig(seedRPCServerAddr: await Global.getSeedRpcList())).then((balance) {
            logger.d("$TAG - queryBalance: END - balance_old:${w.balance} - balance_new:$balance - nkn_address:${w.address}");
            if (w.balance != balance) {
              w.balance = balance;
              _walletBloc.add(UpdateWallet(w));
            }
          }).catchError((e) {
            handleError(e);
          });
        }
      });
    }
  }
}
