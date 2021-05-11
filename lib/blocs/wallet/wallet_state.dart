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

  Future<bool> isAllWalletBackup() {
    return WalletStorage().isAllBackup();
  }
}
