import 'package:nmobile/schema/wallet.dart';

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
    return wallets.isEmpty;
  }
}

// backup
class WalletBackup extends WalletLoaded {
  final List<WalletSchema> wallets;

  final String walletAddress;
  final bool allBackup;

  WalletBackup(this.wallets, this.walletAddress, this.allBackup) : super(wallets);
}

// default
class WalletDefault extends WalletLoaded {
  final List<WalletSchema> wallets;

  final String walletAddress;

  WalletDefault(this.wallets, this.walletAddress) : super(wallets);
}
