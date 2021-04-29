import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';

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
    if (event is Load) {
      yield* _mapLoadWalletsToState();
    } else if (event is Add) {
      yield* _mapAddWalletToState(event);
    } else if (event is Delete) {
      yield* _mapDeleteWalletToState(event);
    } else if (event is Update) {
      yield* _mapUpdateWalletToState(event);
    }
  }

  Stream<WalletState> _mapLoadWalletsToState() async* {
    var wallets = await _walletStorage.getWallets();
    yield Loaded(wallets);
  }

  Stream<WalletState> _mapAddWalletToState(Add event) async* {
    if (state is Loaded) {
      _walletStorage.addWallet(event.wallet, event.keystore);
      final List<WalletSchema> list = List.from((state as Loaded).wallets)..add(event.wallet);
      yield Loaded(list);
    }
  }

  Stream<WalletState> _mapDeleteWalletToState(Delete event) async* {
    if (state is Loaded) {
      final List<WalletSchema> list = List.from((state as Loaded).wallets);
      int index = list.indexOf(event.wallet);
      list.removeAt(index);
      yield Loaded(list);
      _walletStorage.deleteWallet(index, event.wallet);
    }
  }

  Stream<WalletState> _mapUpdateWalletToState(Update event) async* {
    if (state is Loaded) {
      final List<WalletSchema> list = List.from((state as Loaded).wallets);
      int index = list.indexOf(event.wallet);
      if (index >= 0) {
        list[index] = event.wallet;
        _walletStorage.updateWallet(index, event.wallet);
      }
      yield Loaded(list);
    }
  }
}
