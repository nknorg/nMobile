import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';

import 'home_empty.dart';
import 'home_list.dart';

class WalletHomeScreen extends StatefulWidget {
  static const String routeName = '/wallet/home';

  static go(BuildContext context) {
    Navigator.pushNamed(context, routeName);
  }

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
        if (state is WalletLoaded) {
          return state.isWalletsEmpty() ? WalletHomeEmptyLayout() : WalletHomeListLayout();
        }
        return WalletHomeListLayout();
      },
    );
  }
}
