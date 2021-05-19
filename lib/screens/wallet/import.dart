import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/layout/tabs.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

import 'import_by_keystore.dart';
import 'import_by_seed.dart';

class WalletImportScreen extends StatefulWidget {
  static const String routeName = '/wallet/import';
  static final String argWalletType = "wallet_type";

  static Future go(BuildContext context, String walletType) {
    if (walletType == null || walletType.isEmpty) {
      walletType = WalletType.nkn;
    }
    return Navigator.pushNamed(context, routeName, arguments: {
      argWalletType: walletType,
    });
  }

  final Map<String, dynamic> arguments;

  const WalletImportScreen({Key key, this.arguments}) : super(key: key);

  @override
  _ImportWalletScreenState createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<WalletImportScreen> with SingleTickerProviderStateMixin {
  String _walletType;
  TabController _tabController;

  StreamController<String> _qrController = StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    this._walletType = widget.arguments[WalletImportScreen.argWalletType];
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    _qrController.close();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    List<String> tabTitles = [_localizations.tab_keystore, _localizations.tab_seed];

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: this._walletType == WalletType.eth ? _localizations.import_ethereum_wallet : _localizations.import_nkn_wallet,
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg('scan', width: 24, color: application.theme.backgroundLightColor),
            onPressed: () async {
              if (_tabController.index != 1) {
                _tabController.index = 1;
              }

              var qrData = await Navigator.pushNamed(context, ScannerScreen.routeName);
              logger.d("QR_DATA:$qrData");
              _qrController.sink?.add(qrData);
            },
          )
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 0,
                  child: Tabs(
                    controller: _tabController,
                    titles: tabTitles,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      WalletImportByKeystoreLayout(walletType: this._walletType),
                      WalletImportBySeedLayout(walletType: this._walletType, qrStream: _qrController.stream),
                    ],
                  ),
                ),
              ],
            )),
      ),
    );
  }
}
