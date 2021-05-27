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
  final String? password;
  final String? seed;

  AddWallet(this.wallet, this.keystore, {this.password, this.seed});
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

// backup
class BackupWallet extends WalletEvent {
  final String address;
  final bool backup;

  BackupWallet(this.address, this.backup);
}

// default
class DefaultWallet extends WalletEvent {
  final String address;

  DefaultWallet(this.address);
}
