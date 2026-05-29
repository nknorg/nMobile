import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/screens/wallet/home_list.android.dart';
import 'package:nmobile/screens/wallet/home_list.ios.dart';

class WalletHomeListLayout extends BaseStateFulWidget {
  @override
  _WalletHomeListLayoutState createState() => _WalletHomeListLayoutState();
}

class _WalletHomeListLayoutState extends BaseStateFulWidgetState<WalletHomeListLayout> {
  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return WalletHomeListIOSLayout();
    }
    return WalletHomeListAndroidLayout();
  }
}
