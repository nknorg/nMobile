import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletReceiveNKNScreen extends StatefulWidget {
  static const String routeName = '/wallet/receive_nkn';
  static final String argWallet = "wallet";

  static go(BuildContext context, WalletSchema wallet) {
    logger.d("wallet receive NKN - $wallet");
    if (wallet == null) return;
    Navigator.pushNamed(context, routeName, arguments: {
      argWallet: wallet,
    });
  }

  final Map<String, dynamic> arguments;

  WalletReceiveNKNScreen({Key key, this.arguments}) : super(key: key);

  @override
  _WalletReceiveNKNScreenState createState() => _WalletReceiveNKNScreenState();
}

class _WalletReceiveNKNScreenState extends State<WalletReceiveNKNScreen> {
  GlobalKey globalKey = new GlobalKey();
  WalletSchema _wallet;

  @override
  void initState() {
    super.initState();
    this._wallet = widget.arguments[WalletReceiveNKNScreen.argWallet];
    // balance query
    locator<TaskService>().queryWalletBalanceTask();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: (_localizations.receive + ' ' + _localizations.nkn),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          IconButton(
            icon: assetIcon(
              'share',
              width: 24,
              color: application.theme.backgroundLightColor,
            ),
            onPressed: () async {
              RenderRepaintBoundary boundary = globalKey.currentContext.findRenderObject();
              var image = await boundary.toImage();
              ByteData byteData = await image.toByteData(format: ImageByteFormat.png);
              Uint8List pngBytes = byteData.buffer.asUint8List();
              // TODO:GG share
              // await Share.file('Recieve NKN', 'qrcode.png', pngBytes, 'image/png', text: wallet.address);
            },
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: BlocBuilder<WalletBloc, WalletState>(
                builder: (context, state) {
                  if (state is WalletLoaded) {
                    _wallet = state.getWalletByAddress(_wallet?.address ?? "");
                  }
                  return Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
                        child: WalletDropdown(
                          selectTitle: _localizations.select_asset_to_receive,
                          schema: _wallet,
                        ),
                      ),
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
                                              child: assetIcon(
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
                                size: MediaQuery.of(context).size.width * 0.57,
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
          Expanded(
            flex: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Button(
                        text: _localizations.done,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
