import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

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
    List<WalletSchema> wallets = await _walletStorage.getWallets();
    yield WalletLoaded(wallets);
  }

  Stream<WalletState> _mapAddWalletToState(AddWallet event) async* {
    if (state is WalletLoaded) {
      await _walletStorage.add(event.wallet, event.keystore, password: event.password);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      int index = list.indexWhere((x) => x.address == event.wallet.address);
      if (index >= 0) {
        list[index] = event.wallet;
      } else {
        list.add(event.wallet);
      }
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapDeleteWalletToState(DeleteWallet event) async* {
    WalletSchema wallet = event.wallet;
    if (state is WalletLoaded) {
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      // int index = list.indexOf(wallet);
      int index = list.indexWhere((w) => w.address == wallet.address);
      if (index >= 0) {
        list.removeAt(index);
        await _walletStorage.delete(index, wallet);
      }
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapUpdateWalletToState(UpdateWallet event) async* {
    WalletSchema wallet = event.wallet;
    if (state is WalletLoaded) {
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      // int index = list.indexOf(wallet);
      int index = list.indexWhere((w) => w.address == wallet.address);
      if (index >= 0) {
        list[index] = wallet;
        await _walletStorage.update(index, wallet);
      }
      yield WalletLoaded(list);
    }
  }

  Stream<WalletState> _mapBackupWalletToState(BackupWallet event) async* {
    if (state is WalletLoaded) {
      await _walletStorage.setBackup(event.address, event.backup);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      bool allBackup = await walletCommon.isBackup(original: list);
      yield WalletBackup(list, event.address, allBackup);
    }
  }

  Stream<WalletState> _mapDefaultWalletToState(DefaultWallet event) async* {
    if (state is WalletLoaded) {
      await _walletStorage.setDefaultAddress(event.address);
      final List<WalletSchema> list = List.from((state as WalletLoaded).wallets);
      yield WalletDefault(list, event.address);
    }
  }
}
