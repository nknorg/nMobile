import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/topic.dart';

class TaskService {
  Dio dio = Dio();
  WalletsBloc _walletsBloc;
  Timer _queryNknWalletBalanceTask;
  bool _isInit = false;
  init() {
    if (!_isInit) {
      _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);

      _queryNknWalletBalanceTask = Timer.periodic(Duration(seconds: 60), (timer) {
        queryNknWalletBalanceTask();
      });

      _isInit = true;
    }
  }

  queryNknWalletBalanceTask() {
    var state = _walletsBloc.state;
    if (state is WalletsLoaded) {
      List<Future> futures = <Future>[];
      state.wallets.forEach((w) {
        futures.add(NknWalletPlugin.getBalanceAsync(w.address).then((balance) {
          w.balance = balance;
          _walletsBloc.add(UpdateWallet(w));
        }));
      });
      Future.wait(futures).then((data) {
        _walletsBloc.add(ReLoadWallets());
      });
    }
  }

  queryTopicCountTask() async {
    if (Global.currentChatDb == null) {
      return;
    }
    var topics = await TopicSchema.getAllTopic();
    if (topics != null) {
      topics.forEach((x) {
        x.getTopicCount();
      });
    }
  }
}
