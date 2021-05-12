part of 'wallet_bloc.dart';

abstract class WalletState {
  const WalletState();
}

// loading
class WalletLoading extends WalletState {}

// loaded
class WalletLoaded extends WalletState {
  final List<WalletSchema> wallets;

  WalletLoaded(this.wallets);

  bool isWalletsEmpty() {
    return wallets == null || wallets.isEmpty;
  }

  WalletSchema getWalletByAddress(String address) {
    if (isWalletsEmpty() || address == null || address.length == 0) return null;
    return wallets.firstWhere((x) => x.address == address, orElse: () => null);
  }

  bool isBalanceSame(WalletSchema old) {
    WalletSchema wallet = getWalletByAddress(old?.address);
    if (old == null || wallet == null) return true;
    return old.balance == wallet.balance && old.balanceEth == wallet.balanceEth;
  }

  Future<bool> isAllWalletBackup() async {
    List backups = await WalletStorage().isBackupByList(wallets);
    // logger.d("wallets backup:$backups");
    bool find = backups?.firstWhere((backup) => backup == false || backup == null, orElse: () => true);
    bool allBackup = find == true ? true : false;
    // logger.d("wallets allBackup:$allBackup");
    return allBackup;
  }
}
