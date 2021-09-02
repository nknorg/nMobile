import 'package:nmobile/schema/wallet.dart';

abstract class WalletState {
  const WalletState();
}

// loading
class WalletLoading extends WalletState {}

// loaded
class WalletLoaded extends WalletState {
  final List<WalletSchema> wallets;
  final String? defaultAddress;

  WalletLoaded(this.wallets, this.defaultAddress);

  bool isWalletsEmpty() {
    return wallets.isEmpty;
  }

  WalletSchema? defaultWallet() {
    return this.wallets.firstWhere((element) => element.address == defaultAddress);
  }
}

// default
class WalletDefault extends WalletLoaded {
  final List<WalletSchema> wallets;
  final String? defaultAddress;

  WalletDefault(this.wallets, this.defaultAddress) : super(wallets, defaultAddress);
}
