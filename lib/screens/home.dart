import 'package:flutter/material.dart';
import 'package:nmobile/screens/wallet/wallet.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    return WalletScreen();
  }

  @override
  bool get wantKeepAlive => true;
}
