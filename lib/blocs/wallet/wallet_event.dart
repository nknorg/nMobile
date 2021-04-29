part of 'wallet_bloc.dart';

abstract class WalletEvent {
  const WalletEvent();
}

// load
class Load extends WalletEvent {}

// add
class Add extends WalletEvent {
  final WalletSchema wallet;
  final String keystore;

  Add(this.wallet, this.keystore);
}

// delete
class Delete extends WalletEvent {
  final WalletSchema wallet;

  Delete(this.wallet);
}

// update
class Update extends WalletEvent {
  final WalletSchema wallet;

  Update(this.wallet);
}
