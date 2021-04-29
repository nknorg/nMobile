import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';

import 'home_empty.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        // TODO:GG test
        return WalletHomeEmptyScreen();

        // if (state is WalletStateLoaded) {
        //   // loaded
        //   logger.i("wallets: ${state.wallets.toString()}");
        //   // return WalletHomeList(); // WalletHomeEmpty();
        //   // return state.wallets.isEmpty ? WalletHomeEmpty() : WalletHomeList();
        // }
        // // initial + loading
        // return WalletHomeInitial();
      },
    );
  }
}
