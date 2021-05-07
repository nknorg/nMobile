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
}
