import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletStorage _walletStorage = WalletStorage();

  WalletBloc() : super(null);

  static WalletBloc get(context) {
    return BlocProvider.of<WalletBloc>(context);
  }

  @override
  Stream<WalletState> mapEventToState(WalletEvent event) async* {
    if (event is LoadWallet) {
      yield* _mapLoadWalletsToState();
    } else if (event is AddWallet) {
      yield* _mapAddWalletToState(event);
    } else if (event is DeleteWallet) {
      yield* _mapDeleteWalletToState(event);
    } else if (event is UpdateWallet) {
      yield* _mapUpdateWalletToState(event);
    }
  }

  Stream<WalletState> _mapLoadWalletsToState() async* {
    var wallets = await _walletStorage.getWallets();
    logger.d("wallet:$wallets");
    yield WalletLoaded(wallets);
  }

  Stream<WalletState> _mapAddWalletToState(AddWallet event) async* {
    logger.d("wallet:${event.wallet}, keystore:${event.keystore}");
    if (state is WalletLoaded) {
      // TODO:GG duplicated
      _walletStorage.addWallet(event.wallet, event.keystore, password: event.password);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets)..add(event.wallet);
      logger.d("newList:$list");
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapDeleteWalletToState(DeleteWallet event) async* {
    logger.d("wallet:${event.wallet}");
    if (state is WalletLoaded) {
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      int index = list.indexOf(event.wallet);
      list.removeAt(index);
      logger.d("newList:$list");
      yield WalletLoaded(list);
      _walletStorage.deleteWallet(index, event.wallet);
    }
  }

  Stream<WalletState> _mapUpdateWalletToState(UpdateWallet event) async* {
    logger.d("wallet:${event.wallet}");
    if (state is WalletLoaded) {
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      int index = list.indexOf(event.wallet);
      if (index >= 0) {
        list[index] = event.wallet;
        _walletStorage.updateWallet(index, event.wallet);
      }
      logger.d("newList:$list");
      yield WalletLoaded(list);
    }
  }
}
