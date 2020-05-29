import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_event.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_state.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';

class FilteredWalletsBloc extends Bloc<FilteredWalletsEvent, FilteredWalletsState> {
  final WalletsBloc walletsBloc;
  StreamSubscription walletsSubscription;
  FilteredWalletsBloc({@required this.walletsBloc}) {
    walletsBloc.listen((state) {
      if (state is WalletsLoaded) {
        add(UpdateWallets(state.wallets));
      }
    });
  }

  @override
  FilteredWalletsState get initialState => walletsBloc.state is WalletsLoaded ? FilteredWalletsLoaded((walletsBloc.state as WalletsLoaded).wallets, null) : FilteredWalletsLoading();

  @override
  Stream<FilteredWalletsState> mapEventToState(FilteredWalletsEvent event) async* {
    if (event is LoadWalletFilter) {
      yield* _mapLoadWalletFilterToState(event);
    } else if (event is UpdateWallets) {
      yield* _mapWalletsUpdatedToState(event);
    }
  }

  Stream<FilteredWalletsState> _mapLoadWalletFilterToState(LoadWalletFilter event) async* {
    if (walletsBloc.state is WalletsLoaded) {
      var wallets = (walletsBloc.state as WalletsLoaded).wallets;
      yield FilteredWalletsLoaded(
        event.filter != null ? [wallets.singleWhere(event.filter, orElse: () => null)] : [wallets.first],
        event.filter,
      );
    }
  }

  Stream<FilteredWalletsState> _mapWalletsUpdatedToState(UpdateWallets event) async* {
    var actionFilter = state is FilteredWalletsLoaded ? (state as FilteredWalletsLoaded).filter : null;
    var wallets = (walletsBloc.state as WalletsLoaded).wallets;
    yield FilteredWalletsLoaded(
      actionFilter != null ? wallets.where(actionFilter).toList() : wallets,
      actionFilter,
    );
  }

  @override
  Future<void> close() {
    walletsSubscription.cancel();
    return super.close();
  }
}
