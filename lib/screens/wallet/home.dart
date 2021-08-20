import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/screens/wallet/home_empty.dart';
import 'package:nmobile/screens/wallet/home_list.dart';

class WalletHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/home';

  static go(BuildContext context) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  _WalletHomeScreenState createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends BaseStateFulWidgetState<WalletHomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void onRefreshArguments() {}

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
