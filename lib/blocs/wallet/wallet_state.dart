part of 'wallet_bloc.dart';

abstract class WalletState {
  const WalletState();
}

// loading
class Loading extends WalletState {}

// loaded
class Loaded extends WalletState {
  final List<WalletSchema> wallets;

  Loaded(this.wallets);
}
