import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/wallet.dart';

typedef WalletFilterFunc(WalletSchema wallet);

abstract class FilteredWalletsEvent extends Equatable {
  const FilteredWalletsEvent();
}

class LoadWalletFilter extends FilteredWalletsEvent {
  final WalletFilterFunc filter;

  const LoadWalletFilter(this.filter);

  @override
  List<Object> get props => [filter];

  @override
  String toString() => 'LoadWalletFilter { filter: $filter }';
}

class UpdateWallets extends FilteredWalletsEvent {
  final List<WalletSchema> wallets;

  const UpdateWallets(this.wallets);

  @override
  List<Object> get props => [wallets];

  @override
  String toString() => 'UpdateWallets { wallets: $wallets }';
}
