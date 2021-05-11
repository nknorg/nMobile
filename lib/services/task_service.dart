import 'dart:async';

class TaskService {
  bool _isInit = false;
  Timer _queryWalletBalanceTask;

  install() {
    if (!_isInit) {
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
    // TODO:GG wallet_balance
  }
}
