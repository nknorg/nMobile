part of 'wallet_bloc.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object> get props => [];
}

// init
class WalletStateInitial extends WalletState {
  @override
  String toString() {
    return 'WalletInitial{}';
  }
}

// loading
class WalletStateLoading extends WalletState {
  @override
  String toString() {
    return 'WalletLoading{}';
  }
}

// loaded
class WalletStateLoaded extends WalletState {
  final List<WalletSchema> wallets;

  WalletStateLoaded(this.wallets);

  @override
  List<Object> get props => [wallets];

  @override
  String toString() {
    return 'WalletStateLoaded{wallets: $wallets}';
  }
}
