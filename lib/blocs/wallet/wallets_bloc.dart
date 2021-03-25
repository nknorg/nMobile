import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/model/entity/upgrade_rn_wallet.dart';
import 'package:nmobile/model/entity/wallet.dart';
import 'package:nmobile/utils/nlog_util.dart';

class WalletsBloc extends Bloc<WalletsEvent, WalletsState> {
  @override
  WalletsState get initialState => WalletsLoading();

  final LocalStorage _localStorage = LocalStorage();
  final SecureStorage _secureStorage = SecureStorage();

  @override
  Stream<WalletsState> mapEventToState(WalletsEvent event) async* {
    if (event is LoadWallets) {
      await _ensureRnWalletUpgraded();
      yield* _mapLoadWalletsToState();
    } else if (event is AddWallet) {
      yield* _mapAddWalletToState(event);
    } else if (event is DeleteWallet) {
      yield* _mapDeleteWalletToState(event);
    } else if (event is UpdateWallet) {
      yield* _mapUpdateWalletToState(event);
    } else if (event is ReLoadWallets) {
      yield* _mapReloadWalletToState();
    } else if (event is UpdateWalletBackedUp) {
      await _setWalletBackedUp(event);
      yield* _mapReloadWalletToState();
    }
  }

  _ensureRnWalletUpgraded() async {
    final upgraded = await _localStorage.get(LocalStorage.RN_WALLET_UPGRADED);
    if (upgraded == null || !upgraded) {
      final list = await UpgradeRnWallet.rnWalletList;
      if (list != null) {
        for (RnWalletData w in list) {
          final nkn = w.isEth ? w.tokenBalance : w.balance;
          final eth = w.isEth ? w.balance : '0';
          await _addWallet(
              WalletSchema(
                  address: w.address,
                  type: w.isEth
                      ? WalletSchema.ETH_WALLET
                      : WalletSchema.NKN_WALLET,
                  name: w.name,
                  balance: double.parse(nkn),
                  balanceEth: double.parse(eth)),
              w.keystore);
        }
      }
      await _localStorage.set(LocalStorage.RN_WALLET_UPGRADED, true);
    }
  }

  Stream<WalletsState> _mapLoadWalletsToState() async* {
    var wallets = await _localStorage.getArray(LocalStorage.NKN_WALLET_KEY);
    if (wallets != null) {
      final list = wallets.map((x) {
        var wallet = WalletSchema(
            address: x['address'], type: x['type'], name: x['name']);
        if (x['balance'] != null) {
          wallet.balance = x['balance'] ?? 0;
        }
        if (x['balanceEth'] != null) {
          wallet.balanceEth = x['balanceEth'] ?? 0;
        }
        if (x['isBackedUp'] != null) {
          wallet.isBackedUp = x['isBackedUp'];
        }
        return wallet;
      }).toList();
      yield WalletsLoaded(list);
    } else {
      yield WalletsLoaded();
    }
  }

  Stream<WalletsState> _mapReloadWalletToState() async* {
    yield WalletsLoading();
    if (state is WalletsLoaded) {
      final List<WalletSchema> list =
          List.from((state as WalletsLoaded).wallets);
      yield WalletsLoaded(list);
    }
  }

  Stream<WalletsState> _mapAddWalletToState(AddWallet event) async* {
    if (state is WalletsLoaded) {
      _addWallet(event.wallet, event.keystore);

      final List<WalletSchema> list =
          List.from((state as WalletsLoaded).wallets)..add(event.wallet);
      yield WalletsLoaded(list);
    }
  }

  Stream<WalletsState> _mapUpdateWalletToState(UpdateWallet event) async* {
    if (state is WalletsLoaded) {
      final List<WalletSchema> list =
          List.from((state as WalletsLoaded).wallets);
      int index = list.indexOf(event.wallet);
      if (index >= 0) {
        list[index] = event.wallet;
        _setWallet(index, event.wallet);
      }
      yield WalletsLoaded(list);
    }
  }

  Stream<WalletsState> _mapDeleteWalletToState(DeleteWallet event) async* {
    if (state is WalletsLoaded) {
      final List<WalletSchema> list =
          List.from((state as WalletsLoaded).wallets);
      int index = list.indexOf(event.wallet);
      list.removeAt(index);
      yield WalletsLoaded(list);
      _deleteWallet(index, event.wallet);
    }
  }

  _setWalletBackedUp(UpdateWalletBackedUp event) async {
    final address = event.address;
    final List<WalletSchema> list = List.from((state as WalletsLoaded).wallets);
    final wallet =
        list.firstWhere((w) => w.address == address, orElse: () => null);
    if (wallet != null) {
      NLog.d('wallet != null: $wallet');
      int index = list.indexOf(wallet);
      wallet.isBackedUp = true;
      await _setWallet(index, wallet);
    }
  }

  Future _addWallet(WalletSchema wallet, String keystore) async {
    List<Future> futures = <Future>[];
    Map<String, dynamic> data = {
      'name': wallet.name,
      'type': wallet.type,
      'address': wallet.address,
      'isBackedUp': wallet.isBackedUp
    };
    if (wallet.balance != null) {
      data['balance'] = wallet.balance ?? 0;
    }
    if (wallet.balanceEth != null) {
      data['balanceEth'] = wallet.balanceEth ?? 0;
    }
    var wallets = await _localStorage.getArray(LocalStorage.NKN_WALLET_KEY);
    int index =
        wallets?.indexWhere((x) => x['address'] == wallet.address) ?? -1;
    if (index < 0) {
      futures.add(_localStorage.addItem(LocalStorage.NKN_WALLET_KEY, data));
    } else {
      futures
          .add(_localStorage.setItem(LocalStorage.NKN_WALLET_KEY, index, data));
    }
    if (Platform.isAndroid) {
      /// new Comer Android save Keystore to localStorage coz secureStorePlugin bug
      futures.add(_localStorage.saveKeyStoreInFile(wallet.address, keystore));
    } else {
      futures.add(_secureStorage.set(
          '${SecureStorage.NKN_KEYSTORES_KEY}:${wallet.address}', keystore));
    }

    await Future.wait(futures);
  }

  Future _setWallet(int n, WalletSchema wallet) async {
    List<Future> futures = <Future>[];
    Map<String, dynamic> data = {
      'name': wallet.name,
      'type': wallet.type,
      'address': wallet.address,
      'isBackedUp': wallet.isBackedUp
    };
    if (wallet.balance != null) {
      data['balance'] = wallet.balance ?? 0;
    }
    if (wallet.balanceEth != null) {
      data['balanceEth'] = wallet.balanceEth ?? 0;
    }
    futures.add(_localStorage.setItem(LocalStorage.NKN_WALLET_KEY, n, data));
    await Future.wait(futures);
  }

  Future _deleteWallet(int n, WalletSchema wallet) async {
    List<Future> futures = <Future>[];
    futures.add(_localStorage.removeItem(LocalStorage.NKN_WALLET_KEY, n));
    await Future.wait(futures);
  }
}
