import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/image_utils.dart';

class NknWalletExportScreen extends StatefulWidget {
  static const String routeName = '/wallet/nkn_wallet_export';

  final Map arguments;

  NknWalletExportScreen({Key key, this.arguments}) : super(key: key);

  @override
  _NknWalletExportScreenState createState() => _NknWalletExportScreenState();
}

class _NknWalletExportScreenState extends State<NknWalletExportScreen> {
  String keystore;
  String publicKey;
  String seed;
  String address;
  String name;
  WalletsBloc _walletsBloc;

  _setBackupFlag() {
    _walletsBloc.add(UpdateWalletBackedUp(address));
  }

  @override
  void initState() {
    super.initState();
    keystore = widget.arguments['keystore'];
    address = widget.arguments['address'];
    publicKey = widget.arguments['publicKey'];
    seed = widget.arguments['seed'];
    name = widget.arguments['name'];

    _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NMobileLocalizations.of(context).export_wallet,
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 0, left: 20, right: 20),
          color: DefaultTheme.backgroundLightColor,
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.only(top: 0),
                  child: SingleChildScrollView(
                    child: Flex(
                      direction: Axis.vertical,
                      children: <Widget>[
                        Expanded(
                          flex: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Column(
                              children: <Widget>[
                                Hero(
                                  tag: 'avatar:${address}',
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF1F4FF),
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                    child: SvgPicture.asset('assets/logo.svg', color: Color(0xFF253A7E)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 16, bottom: 40),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Label(
                                        name ?? '',
                                        type: LabelType.h2,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 0,
                                  child: Column(
                                    children: <Widget>[
                                      Flex(
                                        direction: Axis.horizontal,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            flex: 0,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 0, right: 20),
                                              child: loadAssetIconsImage(
                                                'wallet',
                                                color: DefaultTheme.primaryColor,
                                                width: 24,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: <Widget>[
                                                      Label(
                                                        NMobileLocalizations.of(context).wallet_address,
                                                        type: LabelType.h4,
                                                        textAlign: TextAlign.start,
                                                      ),
                                                      InkWell(
                                                        child: Label(
                                                          NMobileLocalizations.of(context).copy,
                                                          color: DefaultTheme.primaryColor,
                                                          type: LabelType.bodyRegular,
                                                        ),
                                                        onTap: () {
                                                          CopyUtils.copyAction(context, address);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      CopyUtils.copyAction(context, address);
                                                    },
                                                    child: Textbox(
                                                      value: address,
                                                      readOnly: true,
                                                      enabled: false,
                                                      textInputAction: TextInputAction.next,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Flex(
                                        direction: Axis.horizontal,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            flex: 0,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 0, right: 20),
                                              child: loadAssetIconsImage(
                                                'key',
                                                color: DefaultTheme.primaryColor,
                                                width: 24,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: <Widget>[
                                                      Label(
                                                        NMobileLocalizations.of(context).public_key,
                                                        type: LabelType.h4,
                                                        textAlign: TextAlign.start,
                                                      ),
                                                      InkWell(
                                                        child: Label(
                                                          NMobileLocalizations.of(context).copy,
                                                          color: DefaultTheme.primaryColor,
                                                          type: LabelType.bodyRegular,
                                                        ),
                                                        onTap: () {
                                                          CopyUtils.copyAction(context, publicKey);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      CopyUtils.copyAction(context, publicKey);
                                                    },
                                                    child: Textbox(
                                                      multi: true,
                                                      enabled: false,
                                                      value: publicKey,
                                                      readOnly: true,
                                                      textInputAction: TextInputAction.next,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Flex(
                                        direction: Axis.horizontal,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            flex: 0,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 0, right: 20),
                                              child: loadAssetIconsImage(
                                                'key',
                                                color: DefaultTheme.primaryColor,
                                                width: 24,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: <Widget>[
                                                      Label(
                                                        NMobileLocalizations.of(context).seed,
                                                        type: LabelType.h4,
                                                        textAlign: TextAlign.start,
                                                      ),
                                                      InkWell(
                                                        child: Label(
                                                          NMobileLocalizations.of(context).copy,
                                                          color: DefaultTheme.primaryColor,
                                                          type: LabelType.bodyRegular,
                                                        ),
                                                        onTap: () {
                                                          CopyUtils.copyAction(context, seed);
                                                          _setBackupFlag();
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      CopyUtils.copyAction(context, seed);
                                                      _setBackupFlag();
                                                    },
                                                    child: Textbox(
                                                      multi: true,
                                                      value: seed,
                                                      readOnly: true,
                                                      enabled: false,
                                                      textInputAction: TextInputAction.next,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Flex(
                                        direction: Axis.horizontal,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            flex: 0,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 0, right: 20),
                                              child: loadAssetIconsImage(
                                                'key',
                                                color: DefaultTheme.primaryColor,
                                                width: 24,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: <Widget>[
                                                      Label(
                                                        NMobileLocalizations.of(context).keystore,
                                                        type: LabelType.h4,
                                                        textAlign: TextAlign.start,
                                                      ),
                                                      InkWell(
                                                        child: Label(
                                                          NMobileLocalizations.of(context).copy,
                                                          color: DefaultTheme.primaryColor,
                                                          type: LabelType.bodyRegular,
                                                        ),
                                                        onTap: () {
                                                          CopyUtils.copyAction(context, keystore);
                                                          _setBackupFlag();
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      CopyUtils.copyAction(context, keystore);
                                                      _setBackupFlag();
                                                    },
                                                    child: Textbox(
                                                      multi: true,
                                                      maxLines: 8,
                                                      enabled: false,
                                                      value: keystore,
                                                      readOnly: true,
                                                      textInputAction: TextInputAction.next,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8, top: 8),
                    child: Column(
                      children: <Widget>[
                        Button(
                          child: Label(
                            NMobileLocalizations.of(context).view_qrcode,
                            type: LabelType.h3,
                            color: DefaultTheme.primaryColor,
                          ),
                          backgroundColor: DefaultTheme.primaryColor.withAlpha(20),
                          fontColor: DefaultTheme.primaryColor,
                          onPressed: () {
                            BottomDialog.of(context).showQrcodeDialog(
                              title: NMobileLocalizations.of(context).seed + NMobileLocalizations.of(context).qrcode,
                              data: seed,
                            );
                            _setBackupFlag();
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
