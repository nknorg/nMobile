import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/scanner.dart';
import 'package:nmobile/screens/wallet/import_by_seed.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class WalletImportScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/import';
  static final String argWalletType = "wallet_type";

  static Future go(BuildContext? context, String walletType) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argWalletType: walletType,
    });
  }

  final Map<String, dynamic>? arguments;

  const WalletImportScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _ImportWalletScreenState createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState
    extends BaseStateFulWidgetState<WalletImportScreen> with Tag {
  late String _walletType;

  StreamController<String> _qrController = StreamController<String>.broadcast();

  @override
  void onRefreshArguments() {
    this._walletType =
        widget.arguments?[WalletImportScreen.argWalletType] ?? WalletType.nkn;
  }

  @override
  void dispose() {
    _qrController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: this._walletType == WalletType.eth
            ? Settings.locale((s) => s.import_ethereum_wallet, ctx: context)
            : Settings.locale((s) => s.import_nkn_wallet, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: Asset.iconSvg('scan',
                width: 24, color: application.theme.backgroundLightColor),
            onPressed: () async {
              // permission
              PermissionStatus permissionStatus =
                  await Permission.camera.request();
              if (permissionStatus != PermissionStatus.granted) return;
              // scan
              String? qrData =
                  (await Navigator.pushNamed(context, ScannerScreen.routeName))
                      ?.toString()
                      .replaceAll("\n", "")
                      .trim();
              logger.i("$TAG - QR_DATA:$qrData");
              if (qrData != null && qrData.isNotEmpty) {
                _qrController.sink.add(qrData);
              } else {
                ModalDialog.of(Settings.appContext).show(
                  content: Settings.locale((s) => s.error_unknown_nkn_qrcode,
                      ctx: context),
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
          child: WalletImportBySeedLayout(
              walletType: this._walletType, qrStream: _qrController.stream),
        ),
      ),
    );
  }
}
