import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/wallet.dart';

abstract class FilteredWalletsState extends Equatable {
  const FilteredWalletsState();

  @override
  List<Object> get props => [];
}

class FilteredWalletsLoading extends FilteredWalletsState {}

class FilteredWalletsLoaded extends FilteredWalletsState {
  final List<WalletSchema> filteredWallets;
  final Function filter;

  const FilteredWalletsLoaded(
    this.filteredWallets,
    this.filter,
  );

  @override
  List<Object> get props => [filteredWallets, filter];

  @override
  String toString() {
    return 'FilteredWalletsLoaded { filteredWallets: $filteredWallets, filter: $filter }';
  }
}
