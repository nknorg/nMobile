part of 'wallet_bloc.dart';

abstract class WalletEvent {
  const WalletEvent();
}

// load
class LoadWallet extends WalletEvent {}

// add
class AddWallet extends WalletEvent {
  final WalletSchema wallet;
  final String keystore;
  final String password;

  AddWallet(this.wallet, this.keystore, {this.password});
}

// delete
class DeleteWallet extends WalletEvent {
  final WalletSchema wallet;

  DeleteWallet(this.wallet);
}

// update
class UpdateWallet extends WalletEvent {
  final WalletSchema wallet;

  UpdateWallet(this.wallet);
}
