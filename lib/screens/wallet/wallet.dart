import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/screens/wallet/home.dart';
import 'package:nmobile/screens/wallet/no_wallet.dart';
import 'package:nmobile/screens/welcome.dart';

class WalletScreen extends StatefulWidget {
  static const String routeName = '/wallet';
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletsBloc, WalletsState>(
      builder: (context, state) {
        if (state is WalletsLoaded) {
          if (state.wallets.length > 0) {
            return WalletHome();
          } else {
            return NoWalletScreen();
          }
        }
        return NoWalletScreen();
//        return Welcome();
      },
    );
  }
}
