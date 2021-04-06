import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/wallet.dart';

abstract class WalletsState extends Equatable {
  const WalletsState();

  @override
  List<Object> get props => [];
}

class WalletsLoading extends WalletsState {}

class WalletsLoaded extends WalletsState {
  final List<WalletSchema> wallets;

  const WalletsLoaded([this.wallets = const []]);

  @override
  List<Object> get props => [wallets];

  @override
  String toString() => 'WalletsLoaded { wallets: $wallets }';
}
