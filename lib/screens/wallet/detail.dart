import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/detail.android.dart';
import 'package:nmobile/screens/wallet/detail.ios.dart';

class WalletDetailScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/detail_nkn';
  static final String argWallet = "wallet";
  static final String argListIndex = "list_index";

  static Future go(BuildContext? context, WalletSchema wallet, {int? listIndex}) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argWallet: wallet,
      argListIndex: listIndex,
    });
  }

  final Map<String, dynamic>? arguments;

  const WalletDetailScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _WalletDetailScreenState createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends BaseStateFulWidgetState<WalletDetailScreen> {
  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return WalletDetailIOSScreen(arguments: widget.arguments);
    }
    return WalletDetailAndroidScreen(arguments: widget.arguments);
  }
}
