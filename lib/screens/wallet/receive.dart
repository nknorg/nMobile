import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletReceiveScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/receive';
  static final String argWallet = "wallet";

  static Future go(BuildContext context, WalletSchema wallet) {
    logger.d("WalletReceiveScreen - go - $wallet");
    return Navigator.pushNamed(context, routeName, arguments: {
      argWallet: wallet,
    });
  }

  final Map<String, dynamic>? arguments;

  WalletReceiveScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _WalletReceiveScreenState createState() => _WalletReceiveScreenState();
}

class _WalletReceiveScreenState extends BaseStateFulWidgetState<WalletReceiveScreen> with Tag {
  GlobalKey globalKey = new GlobalKey();
  late WalletSchema _wallet;

  @override
  void onRefreshArguments() {
    this._wallet = widget.arguments![WalletReceiveScreen.argWallet];
  }

  @override
  void initState() {
    super.initState();
    // balance query
    // walletCommon.queryBalance();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: (_localizations.receive + ' ' + _localizations.nkn),
        backgroundColor: application.theme.backgroundColor4,
        // actions: [
        //   IconButton(
        //     icon: Asset.iconSVG(
        //       'share',
        //       width: 24,
        //       color: application.theme.backgroundLightColor,
        //     ),
        //     onPressed: () async {
        //       RenderRepaintBoundary boundary = globalKey.currentContext.findRenderObject();
        //       var image = await boundary.toImage();
        //       ByteData byteData = await image.toByteData(format: ImageByteFormat.png);
        //       Uint8List pngBytes = byteData.buffer.asUint8List();
        //       await Share.file('Recieve NKN', 'qrcode.png', pngBytes, 'image/png', text: wallet.address);
        //     },
        //   )
        // ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: BlocBuilder<WalletBloc, WalletState>(
                builder: (context, state) {
                  if (state is WalletLoaded) {
                    WalletSchema? schema = walletCommon.getInOriginalByAddress(state.wallets, _wallet.address);
                    if (schema != null) {
                      _wallet = schema;
                    }
                  }
                  return Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
                        child: WalletDropdown(
                          selectTitle: _localizations.select_asset_to_receive,
                          wallet: _wallet,
                          onTapWave: false,
                          onSelected: (WalletSchema picked) {
                            logger.d("$TAG - wallet picked - $picked");
                            setState(() {
                              _wallet = picked;
                            });
                          },
                        ),
                      ),
                      Divider(height: 3, indent: 20, endIndent: 20),
                      RepaintBoundary(
                        key: globalKey,
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
                              child: Material(
                                color: application.theme.backgroundColor2,
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                                elevation: 0,
                                child: InkWell(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                  onTap: () {
                                    copyText(_wallet.address, context: context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                    // decoration: BoxDecoration(
                                    //   borderRadius: BorderRadius.all(Radius.circular(8)),
                                    //   color: application.theme.backgroundColor2,
                                    // ),
                                    child: Column(
                                      children: <Widget>[
                                        Label(
                                          _localizations.wallet_address,
                                          type: LabelType.h4,
                                          textAlign: TextAlign.start,
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Label(
                                            _wallet.address,
                                            type: LabelType.bodyRegular,
                                            textAlign: TextAlign.start,
                                            maxLines: 10,
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Asset.iconSvg(
                                                'copy',
                                                width: 24,
                                                color: application.theme.primaryColor,
                                              ),
                                            ),
                                            Label(
                                              _localizations.copy_to_clipboard,
                                              color: application.theme.primaryColor,
                                              type: LabelType.h4,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.only(top: 24),
                              child: QrImage(
                                data: _wallet.address,
                                version: QrVersions.auto,
                                size: Global.screenWidth() * 0.57,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Button(
                      text: _localizations.done,
                      width: double.infinity,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
