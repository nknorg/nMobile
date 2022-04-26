import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:web3dart/web3dart.dart' as Web3;

class WalletCommon with Tag {
  WalletStorage _walletStorage = WalletStorage();
  EthErc20Client _erc20client = EthErc20Client();

  WalletCommon();

  Future<List<WalletSchema>> getWallets() {
    return _walletStorage.getAll();
  }

  Future<String?> getDefaultAddress() {
    return _walletStorage.getDefaultAddress();
  }

  Future<WalletSchema?> getDefault() async {
    String? address = await getDefaultAddress();
    if (address == null || address.isEmpty) return null;
    List<WalletSchema> wallets = await getWallets();
    if (wallets.isEmpty) return null;
    final finds = wallets.where((w) => w.address == address).toList();
    if (finds.isNotEmpty) return finds[0];
    return null;
  }

  Future<String> getKeystore(String? walletAddress) async {
    String? keystore = await _walletStorage.getKeystore(walletAddress);
    if (keystore == null || keystore.isEmpty) {
      throw new Exception("keystore not exits");
    }
    return keystore;
  }

  Future getPassword(String? walletAddress) async {
    if (walletAddress == null || walletAddress.isEmpty) return null;
    return _walletStorage.getPassword(walletAddress);
  }

  Future<bool> isPasswordRight(String? walletAddress, String? password, {List<String>? seedRpcList}) async {
    if (walletAddress == null || walletAddress.isEmpty) return false;
    if (password == null || password.isEmpty) return false;
    String? storagePassword = await getPassword(walletAddress);
    if (storagePassword?.isNotEmpty == true) {
      return password == storagePassword;
    } else {
      try {
        final keystore = await getKeystore(walletAddress);
        seedRpcList = seedRpcList ?? (await Global.getRpcServers(walletAddress, measure: true));
        Wallet nknWallet = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
        if (nknWallet.address.isNotEmpty) return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future getSeed(String? walletAddress) async {
    if (walletAddress == null || walletAddress.isEmpty) return null;
    return _walletStorage.getSeed(walletAddress);
  }

  bool isBalanceSame(WalletSchema? w1, WalletSchema? w2) {
    if (w1 == null || w2 == null) return true;
    return w1.balance == w2.balance && w1.balanceEth == w2.balanceEth;
  }

  queryAllBalance({int? delayMs}) async {
    if (Global.appContext == null) return;
    WalletBloc _walletBloc = BlocProvider.of<WalletBloc>(Global.appContext);
    var state = _walletBloc.state;
    if (state is WalletLoaded) {
      logger.d("$TAG - queryAllBalance");
      for (var i = 0; i < state.wallets.length; i++) {
        WalletSchema wallet = state.wallets[i];
        if (wallet.type == WalletType.eth) {
          await queryETHBalance(wallet, notifyIfNeed: true, delayMs: delayMs);
        } else {
          await queryNKNBalance(wallet, notifyIfNeed: true, delayMs: delayMs);
        }
      }
    }
  }

  Future<double?> queryNKNBalance(WalletSchema wallet, {bool notifyIfNeed = false, int? delayMs}) async {
    if (Global.appContext == null) return null;
    if (wallet.address.isEmpty || wallet.type == WalletType.eth) return null;
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    WalletBloc _walletBloc = BlocProvider.of<WalletBloc>(Global.appContext);
    try {
      final seedRpcList = await Global.getRpcServers(wallet.address, measure: true);
      double balance = await Wallet.getBalanceByAddr(wallet.address, config: WalletConfig(seedRPCServerAddr: seedRpcList));
      logger.d("$TAG - queryNKNBalance - old:${wallet.balance} - new:$balance - wallet_address:${wallet.address}");
      if (notifyIfNeed && (wallet.balance != balance)) {
        wallet.balance = balance;
        _walletBloc.add(UpdateWallet(wallet));
      }
      return balance;
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<double?>> queryETHBalance(WalletSchema wallet, {bool notifyIfNeed = false, int? delayMs}) async {
    if (Global.appContext == null) return [null, null];
    if (wallet.address.isEmpty || wallet.type == WalletType.nkn) return [null, null];
    if (delayMs != null) await Future.delayed(Duration(milliseconds: delayMs));
    WalletBloc _walletBloc = BlocProvider.of<WalletBloc>(Global.appContext);
    try {
      Web3.EtherAmount? ethAmount = await _erc20client.getBalanceEth(address: wallet.address);
      Web3.EtherAmount? nknAmount = await _erc20client.getBalanceNkn(address: wallet.address);
      logger.d("$TAG - queryETHBalance - eth - old:${wallet.balanceEth} - new:${ethAmount?.ether} - wallet_address:${wallet.address}");
      logger.d("$TAG - queryETHBalance - nkn - old:${wallet.balance} - new:${nknAmount?.ether} - wallet_address:${wallet.address}");
      bool ethDiff = (ethAmount != null) && (wallet.balanceEth != (ethAmount.ether as double?));
      bool nknDiff = (nknAmount != null) && (wallet.balance != (nknAmount.ether as double?));
      if (notifyIfNeed && (ethDiff || nknDiff)) {
        wallet.balanceEth = (ethAmount?.ether as double?) ?? 0;
        wallet.balance = (nknAmount?.ether as double?) ?? 0;
        _walletBloc.add(UpdateWallet(wallet));
      }
      return [(ethAmount?.ether as double?), (nknAmount?.ether as double?)];
    } catch (e) {
      handleError(e);
    }
    return [null, null];
  }
}
