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

  Future<bool> isPasswordRight(String? walletAddress, String? password) async {
    if (walletAddress == null || walletAddress.isEmpty) return false;
    if (password == null || password.isEmpty) return false;
    String? storagePassword = await getPassword(walletAddress);
    if (storagePassword?.isNotEmpty == true) {
      return password == storagePassword;
    } else {
      try {
        final keystore = await getKeystore(walletAddress);
        final seedRpcList = await Global.getSeedRpcList(null, measure: false);
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

  queryBalance() async {
    WalletBloc _walletBloc = BlocProvider.of<WalletBloc>(Global.appContext);
    var state = _walletBloc.state;
    if (state is WalletLoaded) {
      logger.d("$TAG - queryBalance: START");
      state.wallets.forEach((w) async {
        if (w.type == WalletType.eth) {
          _erc20client.getBalanceEth(address: w.address).then((balance) {
            logger.d("$TAG - queryBalance: END - eth - old:${w.balanceEth} - new:${balance?.ether} - wallet_address:${w.address}");
            if (balance != null && w.balanceEth != (balance.ether as double?)) {
              w.balanceEth = (balance.ether as double?) ?? 0;
              _walletBloc.add(UpdateWallet(w));
            }
          });
          _erc20client.getBalanceNkn(address: w.address).then((balance) {
            logger.d("$TAG - queryBalance: END - eth_nkn - old:${w.balanceEth} - new:${balance?.ether} - wallet_address:${w.address}");
            if (balance != null && w.balanceEth != (balance.ether as double?)) {
              w.balance = (balance.ether as double?) ?? 0;
              _walletBloc.add(UpdateWallet(w));
            }
          });
        } else {
          final seedRpcList = await Global.getSeedRpcList(null, measure: false);
          Wallet.getBalanceByAddr(w.address, config: WalletConfig(seedRPCServerAddr: seedRpcList)).then((balance) {
            logger.d("$TAG - queryBalance: END - nkn - old:${w.balance} - new:$balance - wallet_address:${w.address}");
            if (w.balance != balance) {
              w.balance = balance;
              _walletBloc.add(UpdateWallet(w));
            }
          }).catchError((e) {
            handleError(e);
          });
        }
      });
    }
  }
}
