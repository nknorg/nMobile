import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/screens/base/screen.dart';

// TODO:GG AutomaticKeepAliveClientMixin 还要吗？
class WalletHomeScreen extends BaseScreen {
  static const String routeName = '/wallet/home';

  @override
  _WalletHomeScreenState createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends BaseScreenState<WalletHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        if (state is WalletStateLoaded) {
          // loaded
          return state.wallets.isNotEmpty ? _WalletHomeList() : _WalletHomeEmpty();
        } else if (state is WalletStateLoading) {
          // loading
          return _WalletHomeLoading();
        }
        // initial
        return _WalletHomeInitial();
      },
    );
  }
}

// list
class _WalletHomeList extends StatefulWidget {
  @override
  __WalletHomeListState createState() => __WalletHomeListState();
}

class __WalletHomeListState extends State<_WalletHomeList> {
  // wallet
  WalletBloc _walletsBloc;
  StreamSubscription<WalletState> _walletSubscription;

  bool _walletsBackedUp = true;

  @override
  void initState() {
    super.initState();

    _walletsBloc = WalletBloc.get(context);
    _walletSubscription = _walletsBloc?.stream?.listen((state) {
      // backup
      _walletsBackedUp = true;
      if (state is WalletStateLoaded) {
        state.wallets?.forEach((wallet) {
          _walletsBackedUp = wallet.isBackedUp && _walletsBackedUp;
          if (!_walletsBackedUp) return; // TODO:GG return到哪里了
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _walletSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: Center(child: Text("list")));
  }
}

// empty
class _WalletHomeEmpty extends StatefulWidget {
  @override
  __WalletHomeEmptyState createState() => __WalletHomeEmptyState();
}

class __WalletHomeEmptyState extends State<_WalletHomeEmpty> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Center(child: Text("empty")));
  }
}

// loading
class _WalletHomeLoading extends StatefulWidget {
  @override
  __WalletHomeLoadingState createState() => __WalletHomeLoadingState();
}

class __WalletHomeLoadingState extends State<_WalletHomeLoading> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Center(child: Text("loading")));
  }
}

// initial
class _WalletHomeInitial extends StatefulWidget {
  @override
  __WalletHomeInitialState createState() => __WalletHomeInitialState();
}

class __WalletHomeInitialState extends State<_WalletHomeInitial> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Center(child: Text("initial")));
  }
}
