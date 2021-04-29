import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/logger.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc() : super(WalletStateInitial());

  static WalletBloc get(context) {
    return BlocProvider.of<WalletBloc>(context);
  }

  @override
  Stream<WalletState> mapEventToState(WalletEvent event) async* {
    // TODO:GG implement mapEventToState
    logger.i("wallet_bloc " + event.toString());
    if (event is WalletEventLoad) {
      yield* _onLoadedWallet(event);
    } else if (event is WalletEventReload) {
      yield* _onLoadedWallet(event);
    } else if (event is WalletEventAdd) {
      yield* _onLoadedWallet(event);
    } else if (event is WalletEventDel) {
      yield* _onLoadedWallet(event);
    } else if (event is WalletEventUpd) {
      yield* _onLoadedWallet(event);
    } else if (event is WalletEventUpdBalance) {
      yield* _onLoadedWallet(event);
    } else if (event is WalletEventUpdBackedUp) {
      yield* _onLoadedWallet(event);
    }
  }

  Stream<WalletState> _onLoadedWallet(event) async* {
    var testWallet = WalletSchema(address: "地址!!!!", type: WalletType.nkn, name: "昵称！！！！！"); // 不是从event获取哦
    // TODO:GG 1.先检查SP，看SP里有没有wallets，没有就走2，有就走3
    // TODO:GG 2.先check下开启app后有没有拉取过，有就走3，没有就从SQLite里获取Wallet，然后放至SP里
    // TODO:GG 3.从SP里获取wallets，再校验数据做容错处理
    var wallets = [testWallet, testWallet];
    logger.i("_onLoadedWallet " + wallets.toString());
    yield WalletStateLoaded(wallets);
  }
}
