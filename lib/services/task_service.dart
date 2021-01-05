import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/model/eth_erc20_token.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/log_tag.dart';

class TaskService with Tag {
  Dio dio = Dio();
  WalletsBloc _walletsBloc;
  EthErc20Client _erc20client;
  Timer _queryNknWalletBalanceTask;
  bool _isInit = false;

  init() {
    if (!_isInit) {
      _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);
      _erc20client = EthErc20Client();
      _queryNknWalletBalanceTask = Timer.periodic(Duration(seconds: 60), (timer) {
        queryNknWalletBalanceTask();
      });

      _isInit = true;
    }
  }

  queryNknWalletBalanceTask() {
    var state = _walletsBloc.state;
    if (state is WalletsLoaded) {
      Global.debugLog('queryNknWalletBalanceTask begin');
      List<Future> futures = <Future>[];
      state.wallets.forEach((w) {
        if (w.type == WalletSchema.ETH_WALLET) {
          futures.add(_erc20client.getBalance(address: w.address).then((balance) {
            Global.debugLog('Get Wallet:${w.name} | balance: ${balance.ether}');
            w.balanceEth = balance.ether;
            _walletsBloc.add(UpdateWallet(w));
          }));
          futures.add(_erc20client.getNknBalance(address: w.address).then((balance) {
            if (balance != null) {
              Global.debugLog('Get Wallet:${w.name} | balance: ${balance.ether}');
              w.balance = balance.ether;
              _walletsBloc.add(UpdateWallet(w));
            }
          }));
        } else {
          futures.add(NknWalletPlugin.
          getBalanceAsync(w.address).then((balance) {
            w.balance = balance;
            _walletsBloc.add(UpdateWallet(w));
          }));
        }
      });
      Global.debugLog('queryNknWalletBalanceTask end');
      Future.wait(futures).then((data) {
        _walletsBloc.add(ReLoadWallets());
        Global.debugLog('queryNknWalletBalanceTask Future.wait(futures)');
      });
    }
  }
}
