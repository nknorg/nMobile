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
    } else if (event is BackupWallet) {
      yield* _mapBackupWalletToState(event);
    } else if (event is DefaultWallet) {
      yield* _mapDefaultWalletToState(event);
    }
  }

  Stream<WalletState> _mapLoadWalletsToState() async* {
    var wallets = await _walletStorage.getWallets();
    logger.d("wallets get - ${wallets.toString()}");
    yield WalletLoaded(wallets);
  }

  Stream<WalletState> _mapAddWalletToState(AddWallet event) async* {
    logger.d("wallet add - ${event.wallet}, keystore:${event.keystore}");
    if (state is WalletLoaded) {
      await _walletStorage.addWallet(event.wallet, event.keystore, password: event.password, seed: event.seed);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      int index = list?.indexWhere((x) => x?.address == event?.wallet?.address) ?? -1;
      if (index >= 0) {
        list[index] = event.wallet;
      } else {
        list.add(event.wallet);
      }
      logger.d("new add list:${list.toString()}");
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapDeleteWalletToState(DeleteWallet event) async* {
    WalletSchema wallet = event?.wallet;
    logger.d("wallet delete - $wallet");
    if (state is WalletLoaded) {
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      // int index = list.indexOf(wallet);
      int index = list?.indexWhere((w) => w?.address == wallet?.address) ?? -1;
      if (index >= 0) {
        list.removeAt(index);
        await _walletStorage.deleteWallet(index, wallet);
      }
      logger.d("new delete list:${list.toString()}");
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapUpdateWalletToState(UpdateWallet event) async* {
    WalletSchema wallet = event?.wallet;
    logger.d("wallet update - $wallet");
    if (state is WalletLoaded) {
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      // int index = list.indexOf(wallet);
      int index = list?.indexWhere((w) => w?.address == wallet?.address) ?? -1;
      if (index >= 0) {
        list[index] = wallet;
        await _walletStorage.updateWallet(index, wallet);
      } else {
        logger.e("no find $wallet");
      }
      logger.d("new update list:${list.toString()}");
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapBackupWalletToState(BackupWallet event) async* {
    logger.d("wallet backup - address:${event.address}, backup:${event.backup}");
    if (state is WalletLoaded) {
      await _walletStorage.backupWallet(event.address, event.backup);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      logger.d("new backup list:${list.toString()}");
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapDefaultWalletToState(DefaultWallet event) async* {
    logger.d("wallet default - address:${event.address}}");
    if (state is WalletLoaded) {
      await _walletStorage.setDefaultAddress(event.address);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      logger.d("new default list:${list.toString()}");
      yield WalletLoaded(list);
    }
  }
}
