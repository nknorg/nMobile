import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class TaskService with Tag {
  bool _isInit = false;
  WalletBloc? _walletBloc;
  // EthErc20Client _erc20client;
  Timer? _queryWalletBalanceTask;

  install() {
    if (!_isInit) {
      _walletBloc = BlocProvider.of<WalletBloc>(Global.appContext);
      // _erc20client = EthErc20Client();
      _queryWalletBalanceTask = Timer.periodic(Duration(seconds: 60), (timer) {
        queryWalletBalanceTask();
      });
      queryWalletBalanceTask();
      _isInit = true;
    }
  }

  uninstall() {
    _queryWalletBalanceTask?.cancel();
  }

  queryWalletBalanceTask() {
    var state = _walletBloc?.state;
    if (state is WalletLoaded) {
      logger.d("$TAG - queryWalletBalanceTask: START");
      List<Future> futures = <Future>[];
      state.wallets.forEach((w) {
        if (w.type == WalletType.eth) {
          // TODO:GG eth balance query
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
          Wallet.getBalanceByAddr(w.address).then((balance) {
            logger.d("$TAG - queryWalletBalanceTask: END - balance_old:${w.balance} - balance_new:$balance - nkn_address:${w.address}");
            if (w.balance != balance) {
              w.balance = balance;
              _walletBloc?.add(UpdateWallet(w));
            }
          }).catchError((e) {
            logger.e(e);
          });
        }
      });
    }
  }
}
