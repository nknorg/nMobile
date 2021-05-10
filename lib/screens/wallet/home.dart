import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';

import 'home_empty.dart';
import 'home_list.dart';

class WalletHomeScreen extends StatefulWidget {
  static const String routeName = '/wallet/home';

  @override
  _WalletHomeScreenState createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // init wallets TODO:GG UI有延迟
    WalletBloc _walletBloc = BlocProvider.of<WalletBloc>(context);
    _walletBloc.add(LoadWallet());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        if (state is WalletLoaded) {
          return state.isWalletsEmpty() ? WalletHomeEmptyLayout() : WalletHomeListLayout();
        }
        return Center(
          child: CircularProgressIndicator(),
        ); // TODO:GG loading
      },
    );
  }
}
