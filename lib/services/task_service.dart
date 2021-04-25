import 'dart:async';


class TaskService {
  bool _isInit = false;
  Timer _queryNConnectWalletBalanceTask;

  install() {
    if (!_isInit) {
      _queryNConnectWalletBalanceTask = Timer.periodic(Duration(seconds: 60), (timer) {
        queryNConnectWalletBalanceTask();
      });
      queryNConnectWalletBalanceTask();
      _isInit = true;
    }
  }

  uninstall (){
    _queryNConnectWalletBalanceTask?.cancel();
  }

  queryNConnectWalletBalanceTask(){

  }
}