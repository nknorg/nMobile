import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/wallet.dart';

abstract class WalletsEvent extends Equatable {
  const WalletsEvent();

  @override
  List<Object> get props => [];
}

class LoadWallets extends WalletsEvent {}

class ReLoadWallets extends WalletsEvent {}

class UpdateWalletsBalance extends WalletsEvent {}

class AddWallet extends WalletsEvent {
  final WalletSchema wallet;
  final String keystore;
  const AddWallet(this.wallet, this.keystore);

  @override
  List<Object> get props => [wallet];

  @override
  String toString() => 'AddWallet { wallet: $wallet }';
}

class UpdateWallet extends WalletsEvent {
  final WalletSchema wallet;
  const UpdateWallet(this.wallet);

  @override
  List<Object> get props => [wallet];

  @override
  String toString() => 'UpdateWallet { wallet: $wallet }';
}

class UpdateWalletBackedUp extends WalletsEvent {
  final String address;
  const UpdateWalletBackedUp(this.address);

  @override
  List<Object> get props => [address];

  @override
  String toString() => 'UpdateWalletBackedUp { address: $address }';
}

class DeleteWallet extends WalletsEvent {
  final WalletSchema wallet;

  const DeleteWallet(this.wallet);

  @override
  List<Object> get props => [wallet];

  @override
  String toString() => 'DeleteWallet { wallet: $wallet }';
}
