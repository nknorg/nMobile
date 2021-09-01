import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> with Tag {
  WalletStorage _walletStorage = WalletStorage();

  WalletBloc() : super(WalletLoading());

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
    List<WalletSchema> wallets = await _walletStorage.getAll();
    String? defaultAddress = await _walletStorage.getDefaultAddress();
    yield WalletLoaded(wallets, defaultAddress);
  }

  Stream<WalletState> _mapAddWalletToState(AddWallet event) async* {
    await _walletStorage.add(event.wallet, event.keystore, event.password, event.seed);
    List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
    int index = list.indexWhere((x) => x.address == event.wallet.address); // int index = list.indexOf(wallet);
    if (index >= 0) {
      list[index] = event.wallet;
    } else {
      list.add(event.wallet);
    }
    String? defaultAddress = await _walletStorage.getDefaultAddress();
    yield WalletLoaded(list, defaultAddress);
  }

  Stream<WalletState> _mapDeleteWalletToState(DeleteWallet event) async* {
    String deleteAddress = event.address;
    List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
    int index = list.indexWhere((w) => w.address == deleteAddress); // int index = list.indexOf(wallet);
    if (index >= 0) {
      list.removeAt(index);
      await _walletStorage.delete(index, deleteAddress);
    }
    String? defaultAddress = await _walletStorage.getDefaultAddress();
    yield WalletLoaded(list, defaultAddress);
  }

  Stream<WalletState> _mapUpdateWalletToState(UpdateWallet event) async* {
    WalletSchema wallet = event.wallet;
    final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
    int index = list.indexWhere((w) => w.address == wallet.address); // int index = list.indexOf(wallet);
    if (index >= 0) {
      list[index] = wallet;
      await _walletStorage.update(index, wallet);
    }
    String? defaultAddress = await _walletStorage.getDefaultAddress();
    yield WalletLoaded(list, defaultAddress);
  }

  Stream<WalletState> _mapBackupWalletToState(BackupWallet event) async* {
    String backupAddress = event.address;
    final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
    int index = list.indexWhere((w) => w.address == backupAddress); // int index = list.indexOf(wallet);
    if (index >= 0) {
      list[index].isBackedUp = event.backup;
      await _walletStorage.update(index, list[index]);
    }
    String? defaultAddress = await _walletStorage.getDefaultAddress();
    yield WalletLoaded(list, defaultAddress);
  }

  Stream<WalletState> _mapDefaultWalletToState(DefaultWallet event) async* {
    await _walletStorage.setDefaultAddress(event.address);
    final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
    yield WalletDefault(list, event.address);
  }
}
