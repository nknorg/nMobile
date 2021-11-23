import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/layout/tabs.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/wallet/import_by_keystore.dart';
import 'package:nmobile/screens/wallet/import_by_seed.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class WalletImportScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/import';
  static final String argWalletType = "wallet_type";

  static Future go(BuildContext context, String walletType) {
    return Navigator.pushNamed(context, routeName, arguments: {
      argWalletType: walletType,
    });
  }

  final Map<String, dynamic>? arguments;

  const WalletImportScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _ImportWalletScreenState createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends BaseStateFulWidgetState<WalletImportScreen> with SingleTickerProviderStateMixin, Tag {
  late TabController _tabController;
  late String _walletType;

  StreamController<String> _qrController = StreamController<String>.broadcast();

  @override
  void onRefreshArguments() {
    this._walletType = widget.arguments![WalletImportScreen.argWalletType] ?? WalletType.nkn;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _qrController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> tabTitles = [Global.locale((s) => s.tab_keystore, ctx: context), Global.locale((s) => s.tab_seed, ctx: context)];

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: this._walletType == WalletType.eth ? Global.locale((s) => s.import_ethereum_wallet, ctx: context) : Global.locale((s) => s.import_nkn_wallet, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg('scan', width: 24, color: application.theme.backgroundLightColor),
            onPressed: () async {
              if (_tabController.index != 1) {
                _tabController.index = 1;
              }
              // permission
              PermissionStatus permissionStatus = await Permission.camera.request();
              if (permissionStatus != PermissionStatus.granted) return;
              // scan
              var qrData = await Navigator.pushNamed(context, ScannerScreen.routeName);
              logger.i("$TAG - QR_DATA:$qrData");
              if (qrData != null && qrData.toString().isNotEmpty) {
                _qrController.sink.add(qrData.toString());
              } else {
                ModalDialog.of(Global.appContext).show(
                  content: Global.locale((s) => s.error_unknown_nkn_qrcode, ctx: context),
                  hasCloseButton: true,
                );
              }
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
              Tabs(
                controller: _tabController,
                titles: tabTitles,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    WalletImportByKeystoreLayout(walletType: this._walletType),
                    WalletImportBySeedLayout(walletType: this._walletType, qrStream: _qrController.stream),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
