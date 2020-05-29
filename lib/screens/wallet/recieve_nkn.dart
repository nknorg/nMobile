import 'dart:typed_data';
import 'dart:ui';

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiveNknScreen extends StatefulWidget {
  static const String routeName = '/wallet/recieve_nkn';
  final WalletSchema arguments;

  ReceiveNknScreen({this.arguments});

  @override
  _ReceiveNknScreenState createState() => _ReceiveNknScreenState();
}

class _ReceiveNknScreenState extends State<ReceiveNknScreen> {
  final GetIt locator = GetIt.instance;
  FilteredWalletsBloc _filteredWalletsBloc;
  GlobalKey globalKey = new GlobalKey();
  WalletSchema wallet;

  @override
  void initState() {
    super.initState();
    locator<TaskService>().queryNknWalletBalanceTask();
    _filteredWalletsBloc = BlocProvider.of<FilteredWalletsBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: (NMobileLocalizations.of(context).recieve + ' ' + NMobileLocalizations.of(context).nkn).toUpperCase(),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: IconButton(
          icon: loadAssetIconsImage(
            'share',
            width: 24,
            color: DefaultTheme.backgroundLightColor,
          ),
          onPressed: () async {
            RenderRepaintBoundary boundary = globalKey.currentContext.findRenderObject();
            var image = await boundary.toImage();
            ByteData byteData = await image.toByteData(format: ImageByteFormat.png);
            Uint8List pngBytes = byteData.buffer.asUint8List();
            await Share.file('Recieve NKN', 'qrcode.png', pngBytes, 'image/png', text: wallet.address);
          },
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 0, left: 0, right: 0),
          color: DefaultTheme.backgroundLightColor,
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: BlocBuilder<FilteredWalletsBloc, FilteredWalletsState>(
                    builder: (context, state) {
                      if (state is FilteredWalletsLoaded) {
                        wallet = state.filteredWallets.first;
                        return Flex(
                          direction: Axis.vertical,
                          children: <Widget>[
                            Expanded(
                              flex: 0,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 32, left: 20, right: 20),
                                child: Column(
                                  children: <Widget>[
                                    Expanded(
                                      flex: 0,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Label(
                                                NMobileLocalizations.of(context).to,
                                                type: LabelType.h4,
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                          WalletDropdown(
                                            title: NMobileLocalizations.of(context).select_asset_to_recieve,
                                            schema: widget.arguments ?? wallet,
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 0,
                              child: RepaintBoundary(
                                key: globalKey,
                                child: Column(
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.all(Radius.circular(8)),
                                          color: DefaultTheme.backgroundColor2,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                          child: Column(
                                            children: <Widget>[
                                              Label(
                                                NMobileLocalizations.of(context).wallet_address,
                                                type: LabelType.h4,
                                                textAlign: TextAlign.start,
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                                child: Label(
                                                  wallet.address,
                                                  type: LabelType.bodyRegular,
                                                  textAlign: TextAlign.start,
                                                ),
                                              ),
                                              InkWell(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: <Widget>[
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 8.0),
                                                      child: loadAssetIconsImage(
                                                        'copy',
                                                        width: 24,
                                                        color: DefaultTheme.primaryColor,
                                                      ),
                                                    ),
                                                    Label(
                                                      NMobileLocalizations.of(context).copy_to_clipboard,
                                                      color: DefaultTheme.primaryColor,
                                                      type: LabelType.h4,
                                                    ),
                                                  ],
                                                ),
                                                onTap: () {
                                                  CopyUtils.copyAction(context, wallet.address);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.only(top: 24),
                                      alignment: Alignment.center,
                                      child: QrImage(
                                        data: wallet.address,
                                        backgroundColor: DefaultTheme.backgroundLightColor,
                                        version: QrVersions.auto,
                                        size: 240.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        );
                      } else {
                        return null;
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8, top: 8, left: 20, right: 20),
                    child: Column(
                      children: <Widget>[
                        Button(
                          width: double.infinity,
                          child: Label(
                            NMobileLocalizations.of(context).done,
                            type: LabelType.h3,
                          ),
                          padding: EdgeInsets.only(top: 16, bottom: 16),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
